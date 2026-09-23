import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_kk.dart';
import 'app_localizations_ky.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_uz.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ru'),
    Locale('en'),
    Locale('kk'),
    Locale('ky'),
    Locale('uz'),
  ];

  /// No description provided for @navReports.
  ///
  /// In ru, this message translates to:
  /// **'Отчёты'**
  String get navReports;

  /// No description provided for @navStock.
  ///
  /// In ru, this message translates to:
  /// **'Склад'**
  String get navStock;

  /// Application name
  ///
  /// In ru, this message translates to:
  /// **'TelePOS'**
  String get appName;

  /// No description provided for @globalOk.
  ///
  /// In ru, this message translates to:
  /// **'ОК'**
  String get globalOk;

  /// No description provided for @globalCancel.
  ///
  /// In ru, this message translates to:
  /// **'Отмена'**
  String get globalCancel;

  /// No description provided for @globalYes.
  ///
  /// In ru, this message translates to:
  /// **'Да'**
  String get globalYes;

  /// No description provided for @globalNo.
  ///
  /// In ru, this message translates to:
  /// **'Нет'**
  String get globalNo;

  /// No description provided for @globalSave.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить'**
  String get globalSave;

  /// No description provided for @globalNew.
  ///
  /// In ru, this message translates to:
  /// **'Новый'**
  String get globalNew;

  /// No description provided for @globalDelete.
  ///
  /// In ru, this message translates to:
  /// **'Удалить'**
  String get globalDelete;

  /// No description provided for @globalEdit.
  ///
  /// In ru, this message translates to:
  /// **'Редактировать'**
  String get globalEdit;

  /// No description provided for @globalAdd.
  ///
  /// In ru, this message translates to:
  /// **'Добавить'**
  String get globalAdd;

  /// No description provided for @globalSearch.
  ///
  /// In ru, this message translates to:
  /// **'Поиск'**
  String get globalSearch;

  /// No description provided for @globalClose.
  ///
  /// In ru, this message translates to:
  /// **'Закрыть'**
  String get globalClose;

  /// No description provided for @globalBack.
  ///
  /// In ru, this message translates to:
  /// **'Назад'**
  String get globalBack;

  /// No description provided for @globalNext.
  ///
  /// In ru, this message translates to:
  /// **'Далее'**
  String get globalNext;

  /// No description provided for @globalDone.
  ///
  /// In ru, this message translates to:
  /// **'Готово'**
  String get globalDone;

  /// No description provided for @globalLoading.
  ///
  /// In ru, this message translates to:
  /// **'Загрузка...'**
  String get globalLoading;

  /// No description provided for @globalError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка'**
  String get globalError;

  /// No description provided for @globalSuccess.
  ///
  /// In ru, this message translates to:
  /// **'Успешно'**
  String get globalSuccess;

  /// No description provided for @globalWarning.
  ///
  /// In ru, this message translates to:
  /// **'Внимание'**
  String get globalWarning;

  /// No description provided for @globalInfo.
  ///
  /// In ru, this message translates to:
  /// **'Информация'**
  String get globalInfo;

  /// No description provided for @globalConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Подтвердить'**
  String get globalConfirm;

  /// No description provided for @globalClear.
  ///
  /// In ru, this message translates to:
  /// **'Очистить'**
  String get globalClear;

  /// No description provided for @globalSelect.
  ///
  /// In ru, this message translates to:
  /// **'Выбрать'**
  String get globalSelect;

  /// No description provided for @globalAll.
  ///
  /// In ru, this message translates to:
  /// **'Все'**
  String get globalAll;

  /// No description provided for @globalNone.
  ///
  /// In ru, this message translates to:
  /// **'Нет'**
  String get globalNone;

  /// No description provided for @globalTotal.
  ///
  /// In ru, this message translates to:
  /// **'Итого'**
  String get globalTotal;

  /// No description provided for @globalAmount.
  ///
  /// In ru, this message translates to:
  /// **'Сумма'**
  String get globalAmount;

  /// No description provided for @globalQuantity.
  ///
  /// In ru, this message translates to:
  /// **'Количество'**
  String get globalQuantity;

  /// No description provided for @globalPrice.
  ///
  /// In ru, this message translates to:
  /// **'Цена'**
  String get globalPrice;

  /// No description provided for @globalDiscount.
  ///
  /// In ru, this message translates to:
  /// **'Скидка'**
  String get globalDiscount;

  /// No description provided for @globalDate.
  ///
  /// In ru, this message translates to:
  /// **'Дата'**
  String get globalDate;

  /// No description provided for @globalTime.
  ///
  /// In ru, this message translates to:
  /// **'Время'**
  String get globalTime;

  /// No description provided for @loginTitle.
  ///
  /// In ru, this message translates to:
  /// **'Вход в систему'**
  String get loginTitle;

  /// No description provided for @loginPin.
  ///
  /// In ru, this message translates to:
  /// **'Введите PIN'**
  String get loginPin;

  /// No description provided for @loginPinHint.
  ///
  /// In ru, this message translates to:
  /// **'4 цифры'**
  String get loginPinHint;

  /// No description provided for @loginEnter.
  ///
  /// In ru, this message translates to:
  /// **'Войти'**
  String get loginEnter;

  /// No description provided for @loginSelectUser.
  ///
  /// In ru, this message translates to:
  /// **'Выберите пользователя'**
  String get loginSelectUser;

  /// No description provided for @loginNoUsers.
  ///
  /// In ru, this message translates to:
  /// **'Нет пользователей'**
  String get loginNoUsers;

  /// No description provided for @loginWrongPin.
  ///
  /// In ru, this message translates to:
  /// **'Неверный PIN'**
  String get loginWrongPin;

  /// No description provided for @loginBlocked.
  ///
  /// In ru, this message translates to:
  /// **'Пользователь заблокирован'**
  String get loginBlocked;

  /// No description provided for @loginSessionExpired.
  ///
  /// In ru, this message translates to:
  /// **'Сессия истекла'**
  String get loginSessionExpired;

  /// No description provided for @loginShiftRequired.
  ///
  /// In ru, this message translates to:
  /// **'Откройте смену для входа'**
  String get loginShiftRequired;

  /// No description provided for @staffRoleOwner.
  ///
  /// In ru, this message translates to:
  /// **'Владелец'**
  String get staffRoleOwner;

  /// No description provided for @staffRoleAdministrator.
  ///
  /// In ru, this message translates to:
  /// **'Администратор'**
  String get staffRoleAdministrator;

  /// No description provided for @staffRoleUser.
  ///
  /// In ru, this message translates to:
  /// **'Пользователь'**
  String get staffRoleUser;

  /// No description provided for @staffRoleCashier.
  ///
  /// In ru, this message translates to:
  /// **'Кассир'**
  String get staffRoleCashier;

  /// No description provided for @staffRoleUnknown.
  ///
  /// In ru, this message translates to:
  /// **'Неизвестно'**
  String get staffRoleUnknown;

  /// No description provided for @loginCashier.
  ///
  /// In ru, this message translates to:
  /// **'Кассир'**
  String get loginCashier;

  /// No description provided for @loginAdmin.
  ///
  /// In ru, this message translates to:
  /// **'Администратор'**
  String get loginAdmin;

  /// No description provided for @loginManager.
  ///
  /// In ru, this message translates to:
  /// **'Менеджер'**
  String get loginManager;

  /// No description provided for @loginLogout.
  ///
  /// In ru, this message translates to:
  /// **'Выход'**
  String get loginLogout;

  /// No description provided for @loginSwitchUser.
  ///
  /// In ru, this message translates to:
  /// **'Сменить пользователя'**
  String get loginSwitchUser;

  /// No description provided for @saleTitle.
  ///
  /// In ru, this message translates to:
  /// **'Продажа'**
  String get saleTitle;

  /// No description provided for @saleNewSale.
  ///
  /// In ru, this message translates to:
  /// **'Новая продажа'**
  String get saleNewSale;

  /// No description provided for @saleAddProduct.
  ///
  /// In ru, this message translates to:
  /// **'Добавить товар'**
  String get saleAddProduct;

  /// No description provided for @saleScanBarcode.
  ///
  /// In ru, this message translates to:
  /// **'Сканировать штрих-код'**
  String get saleScanBarcode;

  /// No description provided for @saleEnterBarcode.
  ///
  /// In ru, this message translates to:
  /// **'Введите штрих-код'**
  String get saleEnterBarcode;

  /// No description provided for @saleProductNotFound.
  ///
  /// In ru, this message translates to:
  /// **'Товар не найден'**
  String get saleProductNotFound;

  /// No description provided for @saleEmptyCart.
  ///
  /// In ru, this message translates to:
  /// **'Корзина пуста'**
  String get saleEmptyCart;

  /// No description provided for @saleSubtotal.
  ///
  /// In ru, this message translates to:
  /// **'Подытог'**
  String get saleSubtotal;

  /// No description provided for @saleTax.
  ///
  /// In ru, this message translates to:
  /// **'НДС'**
  String get saleTax;

  /// No description provided for @saleTotalDiscount.
  ///
  /// In ru, this message translates to:
  /// **'Скидка'**
  String get saleTotalDiscount;

  /// No description provided for @saleToPay.
  ///
  /// In ru, this message translates to:
  /// **'К оплате'**
  String get saleToPay;

  /// No description provided for @saleItems.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} товар} few{{count} товара} other{{count} товаров}}'**
  String saleItems(int count);

  /// No description provided for @paymentCardChargeUnsettled.
  ///
  /// In ru, this message translates to:
  /// **'Карта уже проведена на {amount}, и эта сумма не попадёт в чек. Отмените операцию на платёжном терминале.'**
  String paymentCardChargeUnsettled(String amount);

  /// No description provided for @saleRemoveItem.
  ///
  /// In ru, this message translates to:
  /// **'Удалить товар'**
  String get saleRemoveItem;

  /// No description provided for @saleClearCart.
  ///
  /// In ru, this message translates to:
  /// **'Очистить корзину'**
  String get saleClearCart;

  /// No description provided for @saleConfirmClear.
  ///
  /// In ru, this message translates to:
  /// **'Очистить корзину?'**
  String get saleConfirmClear;

  /// No description provided for @saleProceedPayment.
  ///
  /// In ru, this message translates to:
  /// **'Перейти к оплате'**
  String get saleProceedPayment;

  /// No description provided for @saleHold.
  ///
  /// In ru, this message translates to:
  /// **'Отложить'**
  String get saleHold;

  /// No description provided for @saleRecall.
  ///
  /// In ru, this message translates to:
  /// **'Вернуть'**
  String get saleRecall;

  /// No description provided for @saleHeldSales.
  ///
  /// In ru, this message translates to:
  /// **'Отложенные продажи'**
  String get saleHeldSales;

  /// No description provided for @saleNoHeldSales.
  ///
  /// In ru, this message translates to:
  /// **'Нет отложенных продаж'**
  String get saleNoHeldSales;

  /// No description provided for @saleProductSearch.
  ///
  /// In ru, this message translates to:
  /// **'Поиск товаров'**
  String get saleProductSearch;

  /// No description provided for @saleByCategory.
  ///
  /// In ru, this message translates to:
  /// **'По категориям'**
  String get saleByCategory;

  /// No description provided for @saleByName.
  ///
  /// In ru, this message translates to:
  /// **'По названию'**
  String get saleByName;

  /// No description provided for @saleByBarcode.
  ///
  /// In ru, this message translates to:
  /// **'По штрих-коду'**
  String get saleByBarcode;

  /// No description provided for @saleWeight.
  ///
  /// In ru, this message translates to:
  /// **'Вес'**
  String get saleWeight;

  /// No description provided for @saleWeightKg.
  ///
  /// In ru, this message translates to:
  /// **'Вес: {weight} кг'**
  String saleWeightKg(String weight);

  /// No description provided for @saleEnterWeight.
  ///
  /// In ru, this message translates to:
  /// **'Введите вес'**
  String get saleEnterWeight;

  /// No description provided for @saleEnterQuantity.
  ///
  /// In ru, this message translates to:
  /// **'Введите количество'**
  String get saleEnterQuantity;

  /// No description provided for @saleEnterPrice.
  ///
  /// In ru, this message translates to:
  /// **'Введите цену'**
  String get saleEnterPrice;

  /// No description provided for @saleFreePrice.
  ///
  /// In ru, this message translates to:
  /// **'Свободная цена'**
  String get saleFreePrice;

  /// No description provided for @saleMaxDiscount.
  ///
  /// In ru, this message translates to:
  /// **'Макс. скидка: {percent}%'**
  String saleMaxDiscount(String percent);

  /// No description provided for @refundTitle.
  ///
  /// In ru, this message translates to:
  /// **'Возврат'**
  String get refundTitle;

  /// No description provided for @refundNewRefund.
  ///
  /// In ru, this message translates to:
  /// **'Новый возврат'**
  String get refundNewRefund;

  /// No description provided for @refundByReceipt.
  ///
  /// In ru, this message translates to:
  /// **'По чеку'**
  String get refundByReceipt;

  /// No description provided for @refundWithoutReceipt.
  ///
  /// In ru, this message translates to:
  /// **'Без чека'**
  String get refundWithoutReceipt;

  /// No description provided for @refundEnterReceipt.
  ///
  /// In ru, this message translates to:
  /// **'Введите номер чека'**
  String get refundEnterReceipt;

  /// No description provided for @refundReceiptNotFound.
  ///
  /// In ru, this message translates to:
  /// **'Чек не найден'**
  String get refundReceiptNotFound;

  /// No description provided for @refundSelectItems.
  ///
  /// In ru, this message translates to:
  /// **'Выберите товары для возврата'**
  String get refundSelectItems;

  /// No description provided for @refundReason.
  ///
  /// In ru, this message translates to:
  /// **'Причина возврата'**
  String get refundReason;

  /// No description provided for @refundConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Подтвердить возврат'**
  String get refundConfirm;

  /// No description provided for @refundAmount.
  ///
  /// In ru, this message translates to:
  /// **'Сумма возврата'**
  String get refundAmount;

  /// No description provided for @refundComplete.
  ///
  /// In ru, this message translates to:
  /// **'Возврат выполнен'**
  String get refundComplete;

  /// No description provided for @refundCash.
  ///
  /// In ru, this message translates to:
  /// **'Возврат наличными'**
  String get refundCash;

  /// No description provided for @refundCard.
  ///
  /// In ru, this message translates to:
  /// **'Возврат на карту'**
  String get refundCard;

  /// No description provided for @refundConnectionLostHint.
  ///
  /// In ru, this message translates to:
  /// **'Терминал сам вернётся к кассе — работа продолжится с того же места'**
  String get refundConnectionLostHint;

  /// Подписка на черновик возврата оборвалась — состояние с кассы больше не приходит
  ///
  /// In ru, this message translates to:
  /// **'Связь с кассой потеряна'**
  String get refundConnectionLost;

  /// No description provided for @refundNoItems.
  ///
  /// In ru, this message translates to:
  /// **'Нет товаров для возврата'**
  String get refundNoItems;

  /// No description provided for @refundAlreadyRefunded.
  ///
  /// In ru, this message translates to:
  /// **'Товар уже возвращён'**
  String get refundAlreadyRefunded;

  /// No description provided for @refundPartial.
  ///
  /// In ru, this message translates to:
  /// **'Частичный возврат'**
  String get refundPartial;

  /// No description provided for @shiftTitle.
  ///
  /// In ru, this message translates to:
  /// **'Смена'**
  String get shiftTitle;

  /// No description provided for @shiftOpen.
  ///
  /// In ru, this message translates to:
  /// **'Открыть смену'**
  String get shiftOpen;

  /// No description provided for @shiftClose.
  ///
  /// In ru, this message translates to:
  /// **'Закрыть смену'**
  String get shiftClose;

  /// No description provided for @shiftCurrent.
  ///
  /// In ru, this message translates to:
  /// **'Текущая смена'**
  String get shiftCurrent;

  /// No description provided for @shiftNumber.
  ///
  /// In ru, this message translates to:
  /// **'Номер смены: {number}'**
  String shiftNumber(int number);

  /// No description provided for @shiftOpenedAt.
  ///
  /// In ru, this message translates to:
  /// **'Открыта: {time}'**
  String shiftOpenedAt(String time);

  /// No description provided for @shiftCashier.
  ///
  /// In ru, this message translates to:
  /// **'Кассир: {name}'**
  String shiftCashier(String name);

  /// No description provided for @shiftSalesCount.
  ///
  /// In ru, this message translates to:
  /// **'Продаж: {count}'**
  String shiftSalesCount(int count);

  /// No description provided for @shiftRefundsCount.
  ///
  /// In ru, this message translates to:
  /// **'Возвратов: {count}'**
  String shiftRefundsCount(int count);

  /// No description provided for @shiftTotalSales.
  ///
  /// In ru, this message translates to:
  /// **'Сумма продаж'**
  String get shiftTotalSales;

  /// No description provided for @shiftTotalRefunds.
  ///
  /// In ru, this message translates to:
  /// **'Сумма возвратов'**
  String get shiftTotalRefunds;

  /// No description provided for @shiftCashInDrawer.
  ///
  /// In ru, this message translates to:
  /// **'В кассе'**
  String get shiftCashInDrawer;

  /// No description provided for @shiftExpected.
  ///
  /// In ru, this message translates to:
  /// **'Ожидается'**
  String get shiftExpected;

  /// No description provided for @shiftActual.
  ///
  /// In ru, this message translates to:
  /// **'Фактически'**
  String get shiftActual;

  /// No description provided for @shiftDifference.
  ///
  /// In ru, this message translates to:
  /// **'Разница'**
  String get shiftDifference;

  /// No description provided for @shiftXReport.
  ///
  /// In ru, this message translates to:
  /// **'X-отчёт'**
  String get shiftXReport;

  /// No description provided for @shiftZReport.
  ///
  /// In ru, this message translates to:
  /// **'Z-отчёт'**
  String get shiftZReport;

  /// No description provided for @shiftConfirmClose.
  ///
  /// In ru, this message translates to:
  /// **'Закрыть смену?'**
  String get shiftConfirmClose;

  /// No description provided for @shiftAlreadyOpen.
  ///
  /// In ru, this message translates to:
  /// **'Смена уже открыта'**
  String get shiftAlreadyOpen;

  /// No description provided for @shiftNotOpen.
  ///
  /// In ru, this message translates to:
  /// **'Смена не открыта'**
  String get shiftNotOpen;

  /// No description provided for @shiftOpenFirst.
  ///
  /// In ru, this message translates to:
  /// **'Сначала откройте смену'**
  String get shiftOpenFirst;

  /// No description provided for @paymentTitle.
  ///
  /// In ru, this message translates to:
  /// **'Оплата'**
  String get paymentTitle;

  /// No description provided for @paymentCash.
  ///
  /// In ru, this message translates to:
  /// **'Наличные'**
  String get paymentCash;

  /// No description provided for @paymentCard.
  ///
  /// In ru, this message translates to:
  /// **'Карта'**
  String get paymentCard;

  /// No description provided for @paymentKaspi.
  ///
  /// In ru, this message translates to:
  /// **'Kaspi QR'**
  String get paymentKaspi;

  /// No description provided for @paymentBonus.
  ///
  /// In ru, this message translates to:
  /// **'Бонусы'**
  String get paymentBonus;

  /// No description provided for @paymentDebt.
  ///
  /// In ru, this message translates to:
  /// **'В долг'**
  String get paymentDebt;

  /// No description provided for @paymentInstallment.
  ///
  /// In ru, this message translates to:
  /// **'Рассрочка'**
  String get paymentInstallment;

  /// No description provided for @paymentMixed.
  ///
  /// In ru, this message translates to:
  /// **'Смешанная'**
  String get paymentMixed;

  /// No description provided for @paymentEnterAmount.
  ///
  /// In ru, this message translates to:
  /// **'Введите сумму'**
  String get paymentEnterAmount;

  /// No description provided for @paymentRemaining.
  ///
  /// In ru, this message translates to:
  /// **'Осталось: {amount}'**
  String paymentRemaining(String amount);

  /// No description provided for @paymentChange.
  ///
  /// In ru, this message translates to:
  /// **'Сдача: {amount}'**
  String paymentChange(String amount);

  /// No description provided for @paymentComplete.
  ///
  /// In ru, this message translates to:
  /// **'Оплата завершена'**
  String get paymentComplete;

  /// No description provided for @paymentFailed.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка оплаты'**
  String get paymentFailed;

  /// No description provided for @paymentWaitingCard.
  ///
  /// In ru, this message translates to:
  /// **'Ожидание карты...'**
  String get paymentWaitingCard;

  /// No description provided for @paymentWaitingQr.
  ///
  /// In ru, this message translates to:
  /// **'Ожидание QR...'**
  String get paymentWaitingQr;

  /// No description provided for @paymentInsertCard.
  ///
  /// In ru, this message translates to:
  /// **'Вставьте карту'**
  String get paymentInsertCard;

  /// No description provided for @paymentScanQr.
  ///
  /// In ru, this message translates to:
  /// **'Сканируйте QR'**
  String get paymentScanQr;

  /// No description provided for @paymentApproved.
  ///
  /// In ru, this message translates to:
  /// **'Одобрено'**
  String get paymentApproved;

  /// No description provided for @paymentDeclined.
  ///
  /// In ru, this message translates to:
  /// **'Отклонено'**
  String get paymentDeclined;

  /// No description provided for @paymentReceipt.
  ///
  /// In ru, this message translates to:
  /// **'Печать чека'**
  String get paymentReceipt;

  /// No description provided for @paymentNoReceipt.
  ///
  /// In ru, this message translates to:
  /// **'Без чека'**
  String get paymentNoReceipt;

  /// No description provided for @paymentEmail.
  ///
  /// In ru, this message translates to:
  /// **'Отправить на email'**
  String get paymentEmail;

  /// No description provided for @paymentSms.
  ///
  /// In ru, this message translates to:
  /// **'Отправить SMS'**
  String get paymentSms;

  /// No description provided for @historyTitle.
  ///
  /// In ru, this message translates to:
  /// **'История'**
  String get historyTitle;

  /// No description provided for @historyToday.
  ///
  /// In ru, this message translates to:
  /// **'Сегодня'**
  String get historyToday;

  /// No description provided for @historyYesterday.
  ///
  /// In ru, this message translates to:
  /// **'Вчера'**
  String get historyYesterday;

  /// No description provided for @historyThisWeek.
  ///
  /// In ru, this message translates to:
  /// **'Эта неделя'**
  String get historyThisWeek;

  /// No description provided for @historyThisMonth.
  ///
  /// In ru, this message translates to:
  /// **'Этот месяц'**
  String get historyThisMonth;

  /// No description provided for @historyDateRange.
  ///
  /// In ru, this message translates to:
  /// **'Выбрать период'**
  String get historyDateRange;

  /// No description provided for @historyNoSales.
  ///
  /// In ru, this message translates to:
  /// **'Нет продаж за период'**
  String get historyNoSales;

  /// No description provided for @historyReceipt.
  ///
  /// In ru, this message translates to:
  /// **'Чек №{number}'**
  String historyReceipt(String number);

  /// No description provided for @historyReprint.
  ///
  /// In ru, this message translates to:
  /// **'Повторная печать'**
  String get historyReprint;

  /// Слип выпущенного сертификата не дошёл до очереди печати. Сам сертификат при этом выпущен и годен — кассир обязан выдать бумажку иначе.
  ///
  /// In ru, this message translates to:
  /// **'Слип сертификата {number} не напечатался: {reason}'**
  String certificateSlipPrintFailed(String number, String reason);

  /// No description provided for @historyDetails.
  ///
  /// In ru, this message translates to:
  /// **'Подробнее'**
  String get historyDetails;

  /// No description provided for @historySale.
  ///
  /// In ru, this message translates to:
  /// **'Продажа'**
  String get historySale;

  /// No description provided for @historyRefund.
  ///
  /// In ru, this message translates to:
  /// **'Возврат'**
  String get historyRefund;

  /// No description provided for @historyFilter.
  ///
  /// In ru, this message translates to:
  /// **'Фильтр'**
  String get historyFilter;

  /// No description provided for @agentTitle.
  ///
  /// In ru, this message translates to:
  /// **'Контрагенты'**
  String get agentTitle;

  /// No description provided for @agentClients.
  ///
  /// In ru, this message translates to:
  /// **'Клиенты'**
  String get agentClients;

  /// No description provided for @agentSuppliers.
  ///
  /// In ru, this message translates to:
  /// **'Поставщики'**
  String get agentSuppliers;

  /// No description provided for @agentSearch.
  ///
  /// In ru, this message translates to:
  /// **'Поиск контрагента'**
  String get agentSearch;

  /// No description provided for @agentAdd.
  ///
  /// In ru, this message translates to:
  /// **'Добавить контрагента'**
  String get agentAdd;

  /// No description provided for @agentEdit.
  ///
  /// In ru, this message translates to:
  /// **'Редактировать'**
  String get agentEdit;

  /// No description provided for @agentName.
  ///
  /// In ru, this message translates to:
  /// **'Название/ФИО'**
  String get agentName;

  /// No description provided for @agentPhone.
  ///
  /// In ru, this message translates to:
  /// **'Телефон'**
  String get agentPhone;

  /// No description provided for @agentEmail.
  ///
  /// In ru, this message translates to:
  /// **'Email'**
  String get agentEmail;

  /// No description provided for @agentIin.
  ///
  /// In ru, this message translates to:
  /// **'ИИН/БИН'**
  String get agentIin;

  /// No description provided for @agentAddress.
  ///
  /// In ru, this message translates to:
  /// **'Адрес'**
  String get agentAddress;

  /// No description provided for @agentBalance.
  ///
  /// In ru, this message translates to:
  /// **'Баланс'**
  String get agentBalance;

  /// No description provided for @agentBonusBalance.
  ///
  /// In ru, this message translates to:
  /// **'Бонусный баланс'**
  String get agentBonusBalance;

  /// No description provided for @agentDebt.
  ///
  /// In ru, this message translates to:
  /// **'Задолженность'**
  String get agentDebt;

  /// No description provided for @agentNoAgents.
  ///
  /// In ru, this message translates to:
  /// **'Нет контрагентов'**
  String get agentNoAgents;

  /// No description provided for @agentSaveSuccess.
  ///
  /// In ru, this message translates to:
  /// **'Контрагент сохранён'**
  String get agentSaveSuccess;

  /// No description provided for @agentDeleteConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Удалить контрагента?'**
  String get agentDeleteConfirm;

  /// No description provided for @cashTitle.
  ///
  /// In ru, this message translates to:
  /// **'Касса'**
  String get cashTitle;

  /// No description provided for @cashReasonCreditRepayment.
  ///
  /// In ru, this message translates to:
  /// **'Погашение рассрочки'**
  String get cashReasonCreditRepayment;

  /// No description provided for @cashReasonCustomerTopUp.
  ///
  /// In ru, this message translates to:
  /// **'Пополнение счёта покупателя'**
  String get cashReasonCustomerTopUp;

  /// No description provided for @accountBankCard.
  ///
  /// In ru, this message translates to:
  /// **'Банк (карта)'**
  String get accountBankCard;

  /// No description provided for @accountCertificateLiability.
  ///
  /// In ru, this message translates to:
  /// **'Обязательства по сертификатам'**
  String get accountCertificateLiability;

  /// No description provided for @serviceConsumableFallback.
  ///
  /// In ru, this message translates to:
  /// **'Расходник'**
  String get serviceConsumableFallback;

  /// No description provided for @serviceAutoAddedByNorm.
  ///
  /// In ru, this message translates to:
  /// **'Добавлено по норме расхода'**
  String get serviceAutoAddedByNorm;

  /// No description provided for @cashInvestment.
  ///
  /// In ru, this message translates to:
  /// **'Внесение'**
  String get cashInvestment;

  /// No description provided for @cashExpense.
  ///
  /// In ru, this message translates to:
  /// **'Выплата'**
  String get cashExpense;

  /// No description provided for @cashBalance.
  ///
  /// In ru, this message translates to:
  /// **'Баланс кассы'**
  String get cashBalance;

  /// No description provided for @cashEnterAmount.
  ///
  /// In ru, this message translates to:
  /// **'Введите сумму'**
  String get cashEnterAmount;

  /// No description provided for @cashReason.
  ///
  /// In ru, this message translates to:
  /// **'Основание'**
  String get cashReason;

  /// No description provided for @cashReasonPlaceholder.
  ///
  /// In ru, this message translates to:
  /// **'Укажите причину'**
  String get cashReasonPlaceholder;

  /// No description provided for @cashSuccess.
  ///
  /// In ru, this message translates to:
  /// **'Операция выполнена'**
  String get cashSuccess;

  /// No description provided for @cashExpenseTypes.
  ///
  /// In ru, this message translates to:
  /// **'Тип расхода'**
  String get cashExpenseTypes;

  /// No description provided for @discountTitle.
  ///
  /// In ru, this message translates to:
  /// **'Скидка'**
  String get discountTitle;

  /// No description provided for @discountPercent.
  ///
  /// In ru, this message translates to:
  /// **'Процент'**
  String get discountPercent;

  /// No description provided for @discountFixed.
  ///
  /// In ru, this message translates to:
  /// **'Фиксированная'**
  String get discountFixed;

  /// No description provided for @discountEnterValue.
  ///
  /// In ru, this message translates to:
  /// **'Введите значение'**
  String get discountEnterValue;

  /// No description provided for @discountApply.
  ///
  /// In ru, this message translates to:
  /// **'Применить'**
  String get discountApply;

  /// No description provided for @discountRemove.
  ///
  /// In ru, this message translates to:
  /// **'Убрать скидку'**
  String get discountRemove;

  /// No description provided for @discountOnItem.
  ///
  /// In ru, this message translates to:
  /// **'Скидка на товар'**
  String get discountOnItem;

  /// No description provided for @discountOnTotal.
  ///
  /// In ru, this message translates to:
  /// **'Скидка на чек'**
  String get discountOnTotal;

  /// No description provided for @discountMaxExceeded.
  ///
  /// In ru, this message translates to:
  /// **'Превышена максимальная скидка'**
  String get discountMaxExceeded;

  /// No description provided for @quickProductTitle.
  ///
  /// In ru, this message translates to:
  /// **'Быстрые товары'**
  String get quickProductTitle;

  /// No description provided for @quickProductAdd.
  ///
  /// In ru, this message translates to:
  /// **'Добавить товар'**
  String get quickProductAdd;

  /// No description provided for @quickProductName.
  ///
  /// In ru, this message translates to:
  /// **'Название'**
  String get quickProductName;

  /// No description provided for @quickProductPrice.
  ///
  /// In ru, this message translates to:
  /// **'Цена'**
  String get quickProductPrice;

  /// No description provided for @quickProductCategory.
  ///
  /// In ru, this message translates to:
  /// **'Категория'**
  String get quickProductCategory;

  /// No description provided for @quickProductSave.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить'**
  String get quickProductSave;

  /// No description provided for @quickProductDelete.
  ///
  /// In ru, this message translates to:
  /// **'Удалить'**
  String get quickProductDelete;

  /// No description provided for @syncTitle.
  ///
  /// In ru, this message translates to:
  /// **'Синхронизация'**
  String get syncTitle;

  /// No description provided for @syncStatus.
  ///
  /// In ru, this message translates to:
  /// **'Статус синхронизации'**
  String get syncStatus;

  /// No description provided for @syncLastSync.
  ///
  /// In ru, this message translates to:
  /// **'Последняя синхронизация: {time}'**
  String syncLastSync(String time);

  /// No description provided for @syncNow.
  ///
  /// In ru, this message translates to:
  /// **'Синхронизировать'**
  String get syncNow;

  /// No description provided for @syncInProgress.
  ///
  /// In ru, this message translates to:
  /// **'Синхронизация...'**
  String get syncInProgress;

  /// No description provided for @syncSuccess.
  ///
  /// In ru, this message translates to:
  /// **'Синхронизация завершена'**
  String get syncSuccess;

  /// No description provided for @syncFailed.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка синхронизации'**
  String get syncFailed;

  /// No description provided for @syncProducts.
  ///
  /// In ru, this message translates to:
  /// **'Товары'**
  String get syncProducts;

  /// No description provided for @syncPrices.
  ///
  /// In ru, this message translates to:
  /// **'Цены'**
  String get syncPrices;

  /// No description provided for @syncAgents.
  ///
  /// In ru, this message translates to:
  /// **'Контрагенты'**
  String get syncAgents;

  /// No description provided for @syncSales.
  ///
  /// In ru, this message translates to:
  /// **'Продажи'**
  String get syncSales;

  /// No description provided for @syncPending.
  ///
  /// In ru, this message translates to:
  /// **'Ожидают отправки: {count}'**
  String syncPending(int count);

  /// No description provided for @syncOffline.
  ///
  /// In ru, this message translates to:
  /// **'Нет подключения'**
  String get syncOffline;

  /// No description provided for @syncOnline.
  ///
  /// In ru, this message translates to:
  /// **'Подключено'**
  String get syncOnline;

  /// No description provided for @printerTitle.
  ///
  /// In ru, this message translates to:
  /// **'Принтер'**
  String get printerTitle;

  /// No description provided for @printerStatus.
  ///
  /// In ru, this message translates to:
  /// **'Статус принтера'**
  String get printerStatus;

  /// No description provided for @printerConnected.
  ///
  /// In ru, this message translates to:
  /// **'Подключён'**
  String get printerConnected;

  /// No description provided for @printerDisconnected.
  ///
  /// In ru, this message translates to:
  /// **'Отключён'**
  String get printerDisconnected;

  /// No description provided for @printerError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка принтера'**
  String get printerError;

  /// No description provided for @printerPaperOut.
  ///
  /// In ru, this message translates to:
  /// **'Нет бумаги'**
  String get printerPaperOut;

  /// No description provided for @printerConnect.
  ///
  /// In ru, this message translates to:
  /// **'Подключить'**
  String get printerConnect;

  /// No description provided for @printerDisconnect.
  ///
  /// In ru, this message translates to:
  /// **'Отключить'**
  String get printerDisconnect;

  /// No description provided for @printerTest.
  ///
  /// In ru, this message translates to:
  /// **'Тестовая печать'**
  String get printerTest;

  /// No description provided for @printerSettings.
  ///
  /// In ru, this message translates to:
  /// **'Настройки принтера'**
  String get printerSettings;

  /// No description provided for @printerWidth.
  ///
  /// In ru, this message translates to:
  /// **'Ширина чека'**
  String get printerWidth;

  /// No description provided for @additionalTitle.
  ///
  /// In ru, this message translates to:
  /// **'Дополнительно'**
  String get additionalTitle;

  /// No description provided for @additionalSettings.
  ///
  /// In ru, this message translates to:
  /// **'Настройки'**
  String get additionalSettings;

  /// No description provided for @additionalReports.
  ///
  /// In ru, this message translates to:
  /// **'Отчёты'**
  String get additionalReports;

  /// No description provided for @additionalInventory.
  ///
  /// In ru, this message translates to:
  /// **'Инвентаризация'**
  String get additionalInventory;

  /// No description provided for @additionalSupply.
  ///
  /// In ru, this message translates to:
  /// **'Приёмка товара'**
  String get additionalSupply;

  /// No description provided for @additionalPriceChange.
  ///
  /// In ru, this message translates to:
  /// **'Изменение цен'**
  String get additionalPriceChange;

  /// No description provided for @additionalBackup.
  ///
  /// In ru, this message translates to:
  /// **'Резервная копия'**
  String get additionalBackup;

  /// No description provided for @additionalRestore.
  ///
  /// In ru, this message translates to:
  /// **'Восстановление'**
  String get additionalRestore;

  /// No description provided for @additionalUpdate.
  ///
  /// In ru, this message translates to:
  /// **'Обновление'**
  String get additionalUpdate;

  /// No description provided for @additionalAbout.
  ///
  /// In ru, this message translates to:
  /// **'О программе'**
  String get additionalAbout;

  /// No description provided for @additionalLicense.
  ///
  /// In ru, this message translates to:
  /// **'Лицензия'**
  String get additionalLicense;

  /// No description provided for @additionalSupport.
  ///
  /// In ru, this message translates to:
  /// **'Поддержка'**
  String get additionalSupport;

  /// No description provided for @receiptTitle.
  ///
  /// In ru, this message translates to:
  /// **'Чек'**
  String get receiptTitle;

  /// No description provided for @receiptNumber.
  ///
  /// In ru, this message translates to:
  /// **'Чек №'**
  String get receiptNumber;

  /// No description provided for @receiptDate.
  ///
  /// In ru, this message translates to:
  /// **'Дата'**
  String get receiptDate;

  /// No description provided for @receiptCashier.
  ///
  /// In ru, this message translates to:
  /// **'Кассир'**
  String get receiptCashier;

  /// No description provided for @receiptItems.
  ///
  /// In ru, this message translates to:
  /// **'Товары'**
  String get receiptItems;

  /// No description provided for @receiptSubtotal.
  ///
  /// In ru, this message translates to:
  /// **'Подытог'**
  String get receiptSubtotal;

  /// No description provided for @receiptDiscount.
  ///
  /// In ru, this message translates to:
  /// **'Скидка'**
  String get receiptDiscount;

  /// No description provided for @receiptTax.
  ///
  /// In ru, this message translates to:
  /// **'НДС'**
  String get receiptTax;

  /// No description provided for @receiptTotal.
  ///
  /// In ru, this message translates to:
  /// **'ИТОГО'**
  String get receiptTotal;

  /// No description provided for @receiptCash.
  ///
  /// In ru, this message translates to:
  /// **'Наличные'**
  String get receiptCash;

  /// No description provided for @receiptCard.
  ///
  /// In ru, this message translates to:
  /// **'Карта'**
  String get receiptCard;

  /// No description provided for @receiptChange.
  ///
  /// In ru, this message translates to:
  /// **'Сдача'**
  String get receiptChange;

  /// No description provided for @receiptThankYou.
  ///
  /// In ru, this message translates to:
  /// **'Спасибо за покупку!'**
  String get receiptThankYou;

  /// No description provided for @receiptFiscalNumber.
  ///
  /// In ru, this message translates to:
  /// **'Фискальный номер'**
  String get receiptFiscalNumber;

  /// No description provided for @receiptQrCode.
  ///
  /// In ru, this message translates to:
  /// **'QR для проверки'**
  String get receiptQrCode;

  /// No description provided for @receiptCopy.
  ///
  /// In ru, this message translates to:
  /// **'Копия чека'**
  String get receiptCopy;

  /// No description provided for @errorUnknown.
  ///
  /// In ru, this message translates to:
  /// **'Неизвестная ошибка'**
  String get errorUnknown;

  /// No description provided for @errorNetwork.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка сети'**
  String get errorNetwork;

  /// No description provided for @errorServer.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка сервера'**
  String get errorServer;

  /// No description provided for @errorTimeout.
  ///
  /// In ru, this message translates to:
  /// **'Превышено время ожидания'**
  String get errorTimeout;

  /// No description provided for @errorNotFound.
  ///
  /// In ru, this message translates to:
  /// **'Не найдено'**
  String get errorNotFound;

  /// No description provided for @errorPermission.
  ///
  /// In ru, this message translates to:
  /// **'Нет доступа'**
  String get errorPermission;

  /// No description provided for @errorDatabase.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка базы данных'**
  String get errorDatabase;

  /// No description provided for @errorValidation.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка валидации'**
  String get errorValidation;

  /// No description provided for @errorRequired.
  ///
  /// In ru, this message translates to:
  /// **'Обязательное поле'**
  String get errorRequired;

  /// No description provided for @errorInvalidFormat.
  ///
  /// In ru, this message translates to:
  /// **'Неверный формат'**
  String get errorInvalidFormat;

  /// No description provided for @errorMinLength.
  ///
  /// In ru, this message translates to:
  /// **'Минимум {min} символов'**
  String errorMinLength(int min);

  /// No description provided for @errorMaxLength.
  ///
  /// In ru, this message translates to:
  /// **'Максимум {max} символов'**
  String errorMaxLength(int max);

  /// No description provided for @errorMinValue.
  ///
  /// In ru, this message translates to:
  /// **'Минимум {min}'**
  String errorMinValue(String min);

  /// No description provided for @errorMaxValue.
  ///
  /// In ru, this message translates to:
  /// **'Максимум {max}'**
  String errorMaxValue(String max);

  /// No description provided for @errorPrinter.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка принтера'**
  String get errorPrinter;

  /// No description provided for @errorFiscal.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка фискализации'**
  String get errorFiscal;

  /// No description provided for @errorPayment.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка оплаты'**
  String get errorPayment;

  /// No description provided for @errorSync.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка синхронизации'**
  String get errorSync;

  /// No description provided for @errorNoInternet.
  ///
  /// In ru, this message translates to:
  /// **'Нет интернет-соединения'**
  String get errorNoInternet;

  /// No description provided for @errorTryAgain.
  ///
  /// In ru, this message translates to:
  /// **'Попробуйте снова'**
  String get errorTryAgain;

  /// Help dialog title
  ///
  /// In ru, this message translates to:
  /// **'Справка'**
  String get helpTitle;

  /// Tips section header
  ///
  /// In ru, this message translates to:
  /// **'Советы'**
  String get helpTips;

  /// Shortcuts section header
  ///
  /// In ru, this message translates to:
  /// **'Горячие клавиши'**
  String get helpShortcuts;

  /// Related screens section header
  ///
  /// In ru, this message translates to:
  /// **'Связанные разделы'**
  String get helpRelatedScreens;

  /// Shortcut key column header
  ///
  /// In ru, this message translates to:
  /// **'Клавиша'**
  String get helpKey;

  /// Shortcut action column header
  ///
  /// In ru, this message translates to:
  /// **'Действие'**
  String get helpAction;

  /// No description provided for @navSale.
  ///
  /// In ru, this message translates to:
  /// **'Продажа'**
  String get navSale;

  /// No description provided for @navRefund.
  ///
  /// In ru, this message translates to:
  /// **'Возврат'**
  String get navRefund;

  /// No description provided for @navShift.
  ///
  /// In ru, this message translates to:
  /// **'Смена'**
  String get navShift;

  /// No description provided for @navHistory.
  ///
  /// In ru, this message translates to:
  /// **'История'**
  String get navHistory;

  /// No description provided for @navTables.
  ///
  /// In ru, this message translates to:
  /// **'Столы'**
  String get navTables;

  /// No description provided for @navOrders.
  ///
  /// In ru, this message translates to:
  /// **'Заказы'**
  String get navOrders;

  /// No description provided for @navQueue.
  ///
  /// In ru, this message translates to:
  /// **'Очередь'**
  String get navQueue;

  /// No description provided for @navIntake.
  ///
  /// In ru, this message translates to:
  /// **'Приём'**
  String get navIntake;

  /// No description provided for @navAgents.
  ///
  /// In ru, this message translates to:
  /// **'Контрагенты'**
  String get navAgents;

  /// No description provided for @navSupply.
  ///
  /// In ru, this message translates to:
  /// **'Приёмка'**
  String get navSupply;

  /// No description provided for @navCash.
  ///
  /// In ru, this message translates to:
  /// **'Касса'**
  String get navCash;

  /// No description provided for @navSettings.
  ///
  /// In ru, this message translates to:
  /// **'Настройки'**
  String get navSettings;

  /// No description provided for @navSync.
  ///
  /// In ru, this message translates to:
  /// **'Синхронизация'**
  String get navSync;

  /// No description provided for @navMore.
  ///
  /// In ru, this message translates to:
  /// **'Ещё'**
  String get navMore;

  /// No description provided for @navAdditional.
  ///
  /// In ru, this message translates to:
  /// **'Дополнительно'**
  String get navAdditional;

  /// No description provided for @navLockScreen.
  ///
  /// In ru, this message translates to:
  /// **'Блокировка'**
  String get navLockScreen;

  /// No description provided for @navMain.
  ///
  /// In ru, this message translates to:
  /// **'Основное'**
  String get navMain;

  /// No description provided for @loginEnterSystem.
  ///
  /// In ru, this message translates to:
  /// **'Вход в систему'**
  String get loginEnterSystem;

  /// No description provided for @loginWithoutPin.
  ///
  /// In ru, this message translates to:
  /// **'Войти без PIN'**
  String get loginWithoutPin;

  /// No description provided for @loginShiftOpen.
  ///
  /// In ru, this message translates to:
  /// **'Смена открыта'**
  String get loginShiftOpen;

  /// No description provided for @loginShiftClosed.
  ///
  /// In ru, this message translates to:
  /// **'Смена закрыта'**
  String get loginShiftClosed;

  /// No description provided for @loginShiftUnknown.
  ///
  /// In ru, this message translates to:
  /// **'Смена: касса не ответила'**
  String get loginShiftUnknown;

  /// No description provided for @saleQuickProducts.
  ///
  /// In ru, this message translates to:
  /// **'Быстрые товары'**
  String get saleQuickProducts;

  /// No description provided for @saleIncrease.
  ///
  /// In ru, this message translates to:
  /// **'Увеличить'**
  String get saleIncrease;

  /// No description provided for @saleDecrease.
  ///
  /// In ru, this message translates to:
  /// **'Уменьшить'**
  String get saleDecrease;

  /// No description provided for @saleMark.
  ///
  /// In ru, this message translates to:
  /// **'Маркировка'**
  String get saleMark;

  /// No description provided for @saleDataMatrix.
  ///
  /// In ru, this message translates to:
  /// **'Маркировка (DataMatrix)'**
  String get saleDataMatrix;

  /// No description provided for @saleHeld.
  ///
  /// In ru, this message translates to:
  /// **'Чек отложен'**
  String get saleHeld;

  /// No description provided for @saleNoDeferredSales.
  ///
  /// In ru, this message translates to:
  /// **'Нет отложенных чеков'**
  String get saleNoDeferredSales;

  /// Задача 29: причина запертой кнопки «Отложенные» у кассира без права op.deferSale.
  ///
  /// In ru, this message translates to:
  /// **'Отложенные чеки вам не открыты: нужно право «откладывать чек». Его выдаёт администратор в настройках прав; касса откажет любому, у кого его нет.'**
  String get saleDeferredListNotPermitted;

  /// Задача 10 ревизии 2026-09-19: причина запертой кнопки «Отложить» у кассира без права op.deferSale.
  ///
  /// In ru, this message translates to:
  /// **'Отложить чек вам нельзя: нужно право «откладывать чек». Его выдаёт администратор в настройках прав; касса откажет любому, у кого его нет.'**
  String get saleDeferNotPermitted;

  /// No description provided for @saleReceiptNo.
  ///
  /// In ru, this message translates to:
  /// **'Чек №'**
  String get saleReceiptNo;

  /// No description provided for @salePositions.
  ///
  /// In ru, this message translates to:
  /// **'Позиций'**
  String get salePositions;

  /// No description provided for @saleSearchHint.
  ///
  /// In ru, this message translates to:
  /// **'Поиск товара (название или штрих-код)'**
  String get saleSearchHint;

  /// No description provided for @refundWithReceipt.
  ///
  /// In ru, this message translates to:
  /// **'С ЧЕКОМ'**
  String get refundWithReceipt;

  /// No description provided for @refundWithoutReceiptUpper.
  ///
  /// In ru, this message translates to:
  /// **'БЕЗ ЧЕКА'**
  String get refundWithoutReceiptUpper;

  /// No description provided for @refundLoadReceipt.
  ///
  /// In ru, this message translates to:
  /// **'Загрузить чек'**
  String get refundLoadReceipt;

  /// No description provided for @refundSearchProducts.
  ///
  /// In ru, this message translates to:
  /// **'Поиск товаров'**
  String get refundSearchProducts;

  /// No description provided for @refundSelectAll.
  ///
  /// In ru, this message translates to:
  /// **'Выбрать всё'**
  String get refundSelectAll;

  /// No description provided for @refundDeselectAll.
  ///
  /// In ru, this message translates to:
  /// **'Снять всё'**
  String get refundDeselectAll;

  /// No description provided for @refundMaxQuantity.
  ///
  /// In ru, this message translates to:
  /// **'Максимум: {max}'**
  String refundMaxQuantity(String max);

  /// No description provided for @refundConfirmTitle.
  ///
  /// In ru, this message translates to:
  /// **'Подтвердите возврат'**
  String get refundConfirmTitle;

  /// No description provided for @refundSelectedItems.
  ///
  /// In ru, this message translates to:
  /// **'Выбрано позиций: {count}'**
  String refundSelectedItems(int count);

  /// No description provided for @refundSuccessMsg.
  ///
  /// In ru, this message translates to:
  /// **'Возврат успешно проведён'**
  String get refundSuccessMsg;

  /// No description provided for @refundSearchHint.
  ///
  /// In ru, this message translates to:
  /// **'Поиск товара для возврата'**
  String get refundSearchHint;

  /// No description provided for @paymentRefundTitle.
  ///
  /// In ru, this message translates to:
  /// **'Возврат'**
  String get paymentRefundTitle;

  /// No description provided for @paymentPayTitle.
  ///
  /// In ru, this message translates to:
  /// **'Оплата'**
  String get paymentPayTitle;

  /// No description provided for @paymentRefundBtn.
  ///
  /// In ru, this message translates to:
  /// **'ВЕРНУТЬ'**
  String get paymentRefundBtn;

  /// No description provided for @paymentPayBtn.
  ///
  /// In ru, this message translates to:
  /// **'ОПЛАТИТЬ'**
  String get paymentPayBtn;

  /// No description provided for @paymentChangeLabel.
  ///
  /// In ru, this message translates to:
  /// **'Сдача:'**
  String get paymentChangeLabel;

  /// No description provided for @paymentSuccessRefund.
  ///
  /// In ru, this message translates to:
  /// **'Возврат успешно проведён'**
  String get paymentSuccessRefund;

  /// No description provided for @paymentSuccessPay.
  ///
  /// In ru, this message translates to:
  /// **'Оплата успешна'**
  String get paymentSuccessPay;

  /// No description provided for @paymentCardType.
  ///
  /// In ru, this message translates to:
  /// **'Безналичная'**
  String get paymentCardType;

  /// No description provided for @paymentToPay.
  ///
  /// In ru, this message translates to:
  /// **'К оплате'**
  String get paymentToPay;

  /// No description provided for @paymentBonusLabel.
  ///
  /// In ru, this message translates to:
  /// **'Бонусы'**
  String get paymentBonusLabel;

  /// No description provided for @paymentTotalToPay.
  ///
  /// In ru, this message translates to:
  /// **'Итого к оплате'**
  String get paymentTotalToPay;

  /// No description provided for @paymentByCard.
  ///
  /// In ru, this message translates to:
  /// **'Картой'**
  String get paymentByCard;

  /// No description provided for @paymentRemainLabel.
  ///
  /// In ru, this message translates to:
  /// **'Осталось'**
  String get paymentRemainLabel;

  /// No description provided for @shiftBills.
  ///
  /// In ru, this message translates to:
  /// **'Купюры'**
  String get shiftBills;

  /// No description provided for @shiftTotalAmount.
  ///
  /// In ru, this message translates to:
  /// **'Общая сумма'**
  String get shiftTotalAmount;

  /// No description provided for @shiftOperations.
  ///
  /// In ru, this message translates to:
  /// **'Операции'**
  String get shiftOperations;

  /// No description provided for @shiftOpened.
  ///
  /// In ru, this message translates to:
  /// **'Смена открыта'**
  String get shiftOpened;

  /// No description provided for @shiftClosed.
  ///
  /// In ru, this message translates to:
  /// **'Смена закрыта'**
  String get shiftClosed;

  /// No description provided for @shiftOverAgeTitle.
  ///
  /// In ru, this message translates to:
  /// **'Смена открыта более 24 часов'**
  String get shiftOverAgeTitle;

  /// No description provided for @shiftOverAgeMessage.
  ///
  /// In ru, this message translates to:
  /// **'Продажа заблокирована. Закройте текущую смену и откройте новую, чтобы продолжить работу.'**
  String get shiftOverAgeMessage;

  /// No description provided for @shiftOverAgeCloseAtTill.
  ///
  /// In ru, this message translates to:
  /// **'Продажа заблокирована. Закройте смену на кассе и откройте новую, чтобы продолжить работу.'**
  String get shiftOverAgeCloseAtTill;

  /// No description provided for @shiftSince.
  ///
  /// In ru, this message translates to:
  /// **'с {time}'**
  String shiftSince(String time);

  /// No description provided for @shiftSystem.
  ///
  /// In ru, this message translates to:
  /// **'Система'**
  String get shiftSystem;

  /// No description provided for @shiftEntered.
  ///
  /// In ru, this message translates to:
  /// **'Введено'**
  String get shiftEntered;

  /// No description provided for @shiftRecounting.
  ///
  /// In ru, this message translates to:
  /// **'Пересчёт по купюрам'**
  String get shiftRecounting;

  /// No description provided for @shiftManualEntry.
  ///
  /// In ru, this message translates to:
  /// **'Ручной ввод суммы'**
  String get shiftManualEntry;

  /// No description provided for @shiftCashOps.
  ///
  /// In ru, this message translates to:
  /// **'Кассовые операции'**
  String get shiftCashOps;

  /// No description provided for @shiftOpenAction.
  ///
  /// In ru, this message translates to:
  /// **'Открытие смены'**
  String get shiftOpenAction;

  /// No description provided for @shiftCloseAction.
  ///
  /// In ru, this message translates to:
  /// **'Закрытие смены'**
  String get shiftCloseAction;

  /// No description provided for @historyOperations.
  ///
  /// In ru, this message translates to:
  /// **'История операций'**
  String get historyOperations;

  /// No description provided for @historyResetFilters.
  ///
  /// In ru, this message translates to:
  /// **'Сбросить фильтры'**
  String get historyResetFilters;

  /// No description provided for @historyRefresh.
  ///
  /// In ru, this message translates to:
  /// **'Обновить'**
  String get historyRefresh;

  /// No description provided for @historyNoRecords.
  ///
  /// In ru, this message translates to:
  /// **'Нет записей'**
  String get historyNoRecords;

  /// No description provided for @historyChangeFilters.
  ///
  /// In ru, this message translates to:
  /// **'Попробуйте изменить фильтры'**
  String get historyChangeFilters;

  /// No description provided for @historyEmpty.
  ///
  /// In ru, this message translates to:
  /// **'История операций пуста'**
  String get historyEmpty;

  /// No description provided for @historyFilterTitle.
  ///
  /// In ru, this message translates to:
  /// **'Фильтры'**
  String get historyFilterTitle;

  /// No description provided for @historyPeriod.
  ///
  /// In ru, this message translates to:
  /// **'Период'**
  String get historyPeriod;

  /// No description provided for @historyOpType.
  ///
  /// In ru, this message translates to:
  /// **'Тип операции'**
  String get historyOpType;

  /// No description provided for @historySearchHint.
  ///
  /// In ru, this message translates to:
  /// **'Номер чека, сумма...'**
  String get historySearchHint;

  /// No description provided for @historyType.
  ///
  /// In ru, this message translates to:
  /// **'Тип:'**
  String historyType(String type);

  /// No description provided for @historyPrint.
  ///
  /// In ru, this message translates to:
  /// **'Печать чека'**
  String get historyPrint;

  /// No description provided for @agentFound.
  ///
  /// In ru, this message translates to:
  /// **'Найдено: {count}'**
  String agentFound(int count);

  /// No description provided for @agentWithDebt.
  ///
  /// In ru, this message translates to:
  /// **'Только с долгом'**
  String get agentWithDebt;

  /// No description provided for @agentSearchHint.
  ///
  /// In ru, this message translates to:
  /// **'Поиск по имени или телефону...'**
  String get agentSearchHint;

  /// No description provided for @agentNewClient.
  ///
  /// In ru, this message translates to:
  /// **'Новый клиент'**
  String get agentNewClient;

  /// No description provided for @agentNameRequired.
  ///
  /// In ru, this message translates to:
  /// **'Имя *'**
  String get agentNameRequired;

  /// No description provided for @agentEnterName.
  ///
  /// In ru, this message translates to:
  /// **'Введите имя клиента'**
  String get agentEnterName;

  /// No description provided for @agentPhoneLabel.
  ///
  /// In ru, this message translates to:
  /// **'Телефон'**
  String get agentPhoneLabel;

  /// No description provided for @agentIinLabel.
  ///
  /// In ru, this message translates to:
  /// **'БИН/ИИН'**
  String get agentIinLabel;

  /// No description provided for @agentIinHint.
  ///
  /// In ru, this message translates to:
  /// **'12 цифр'**
  String get agentIinHint;

  /// No description provided for @agentDeleteQuestion.
  ///
  /// In ru, this message translates to:
  /// **'Удалить клиента?'**
  String get agentDeleteQuestion;

  /// No description provided for @agentDeleteConfirmMsg.
  ///
  /// In ru, this message translates to:
  /// **'Вы уверены, что хотите удалить {name}?'**
  String agentDeleteConfirmMsg(String name);

  /// No description provided for @agentDeleted.
  ///
  /// In ru, this message translates to:
  /// **'Клиент удалён'**
  String get agentDeleted;

  /// No description provided for @agentFoundExisting.
  ///
  /// In ru, this message translates to:
  /// **'Клиент найден'**
  String get agentFoundExisting;

  /// No description provided for @supplyTitle.
  ///
  /// In ru, this message translates to:
  /// **'Приёмка товара'**
  String get supplyTitle;

  /// No description provided for @supplySaved.
  ///
  /// In ru, this message translates to:
  /// **'Приёмка сохранена'**
  String get supplySaved;

  /// No description provided for @supplySaveError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка сохранения'**
  String get supplySaveError;

  /// No description provided for @supplyCancelQuestion.
  ///
  /// In ru, this message translates to:
  /// **'Отменить приёмку?'**
  String get supplyCancelQuestion;

  /// No description provided for @supplyDataLost.
  ///
  /// In ru, this message translates to:
  /// **'Все введённые данные будут потеряны.'**
  String get supplyDataLost;

  /// No description provided for @supplyProducts.
  ///
  /// In ru, this message translates to:
  /// **'Товаров: {count}'**
  String supplyProducts(int count);

  /// No description provided for @supplyBarcodeHint.
  ///
  /// In ru, this message translates to:
  /// **'Штрихкод или артикул'**
  String get supplyBarcodeHint;

  /// No description provided for @supplyComment.
  ///
  /// In ru, this message translates to:
  /// **'Комментарий'**
  String get supplyComment;

  /// No description provided for @supplyCommentHint.
  ///
  /// In ru, this message translates to:
  /// **'Введите комментарий...'**
  String get supplyCommentHint;

  /// No description provided for @supplyNotFound.
  ///
  /// In ru, this message translates to:
  /// **'Товар не найден'**
  String get supplyNotFound;

  /// No description provided for @supplySelectSupplier.
  ///
  /// In ru, this message translates to:
  /// **'Выберите поставщика'**
  String get supplySelectSupplier;

  /// No description provided for @supplySelectAccount.
  ///
  /// In ru, this message translates to:
  /// **'Выберите счёт'**
  String get supplySelectAccount;

  /// No description provided for @supplyBalance.
  ///
  /// In ru, this message translates to:
  /// **'Баланс: {amount}'**
  String supplyBalance(String amount);

  /// No description provided for @supplyPurchasePrice.
  ///
  /// In ru, this message translates to:
  /// **'Цена прихода'**
  String get supplyPurchasePrice;

  /// No description provided for @supplySerialNumbers.
  ///
  /// In ru, this message translates to:
  /// **'Серийные номера'**
  String get supplySerialNumbers;

  /// No description provided for @supplySerialHint.
  ///
  /// In ru, this message translates to:
  /// **'Введите или отсканируйте S/N'**
  String get supplySerialHint;

  /// No description provided for @supplySerialCount.
  ///
  /// In ru, this message translates to:
  /// **'{count} из {expected}'**
  String supplySerialCount(int count, int expected);

  /// No description provided for @supplySerialMismatch.
  ///
  /// In ru, this message translates to:
  /// **'Число серийных номеров не совпадает с количеством'**
  String get supplySerialMismatch;

  /// No description provided for @supplyInvalidQty.
  ///
  /// In ru, this message translates to:
  /// **'Введите корректное количество'**
  String get supplyInvalidQty;

  /// No description provided for @supplyInvalidPrice.
  ///
  /// In ru, this message translates to:
  /// **'Введите корректную цену'**
  String get supplyInvalidPrice;

  /// No description provided for @inventoryTitle.
  ///
  /// In ru, this message translates to:
  /// **'Инвентаризация'**
  String get inventoryTitle;

  /// No description provided for @inventoryFullCount.
  ///
  /// In ru, this message translates to:
  /// **'Полная инвентаризация'**
  String get inventoryFullCount;

  /// No description provided for @inventoryFullCountSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Обнулить остатки непросканированных товаров'**
  String get inventoryFullCountSubtitle;

  /// No description provided for @inventoryStart.
  ///
  /// In ru, this message translates to:
  /// **'Начать'**
  String get inventoryStart;

  /// No description provided for @inventoryFinish.
  ///
  /// In ru, this message translates to:
  /// **'Завершить'**
  String get inventoryFinish;

  /// No description provided for @inventoryScanHint.
  ///
  /// In ru, this message translates to:
  /// **'Сканируйте штрихкод'**
  String get inventoryScanHint;

  /// No description provided for @inventoryScanProducts.
  ///
  /// In ru, this message translates to:
  /// **'Сканируйте товары для подсчёта'**
  String get inventoryScanProducts;

  /// No description provided for @inventoryPressStart.
  ///
  /// In ru, this message translates to:
  /// **'Нажмите \"Начать\" для инвентаризации'**
  String get inventoryPressStart;

  /// No description provided for @inventoryProductCount.
  ///
  /// In ru, this message translates to:
  /// **'Товаров: {count}'**
  String inventoryProductCount(int count);

  /// No description provided for @inventoryDiscrepancies.
  ///
  /// In ru, this message translates to:
  /// **'Расхождений: {count}'**
  String inventoryDiscrepancies(int count);

  /// No description provided for @inventoryExpected.
  ///
  /// In ru, this message translates to:
  /// **'Ожид:'**
  String get inventoryExpected;

  /// No description provided for @inventoryActual.
  ///
  /// In ru, this message translates to:
  /// **'Факт:'**
  String get inventoryActual;

  /// No description provided for @inventoryProduct.
  ///
  /// In ru, this message translates to:
  /// **'Товар'**
  String get inventoryProduct;

  /// No description provided for @inventoryExpectedQty.
  ///
  /// In ru, this message translates to:
  /// **'Ожидаемое'**
  String get inventoryExpectedQty;

  /// No description provided for @inventoryActualQty.
  ///
  /// In ru, this message translates to:
  /// **'Фактическое'**
  String get inventoryActualQty;

  /// No description provided for @inventoryDiscrepancy.
  ///
  /// In ru, this message translates to:
  /// **'Расхождение'**
  String get inventoryDiscrepancy;

  /// No description provided for @inventoryActualLabel.
  ///
  /// In ru, this message translates to:
  /// **'Фактическое кол-во'**
  String get inventoryActualLabel;

  /// No description provided for @inventoryFinishQuestion.
  ///
  /// In ru, this message translates to:
  /// **'Завершить инвентаризацию?'**
  String get inventoryFinishQuestion;

  /// No description provided for @inventoryCompleted.
  ///
  /// In ru, this message translates to:
  /// **'Инвентаризация завершена'**
  String get inventoryCompleted;

  /// No description provided for @writeoffTitle.
  ///
  /// In ru, this message translates to:
  /// **'Списание'**
  String get writeoffTitle;

  /// No description provided for @writeoffReason.
  ///
  /// In ru, this message translates to:
  /// **'Причина'**
  String get writeoffReason;

  /// No description provided for @writeoffProduct.
  ///
  /// In ru, this message translates to:
  /// **'Товар'**
  String get writeoffProduct;

  /// No description provided for @writeoffScanHint.
  ///
  /// In ru, this message translates to:
  /// **'Сканируйте штрихкод'**
  String get writeoffScanHint;

  /// No description provided for @writeoffCommentHint.
  ///
  /// In ru, this message translates to:
  /// **'Необязательно'**
  String get writeoffCommentHint;

  /// No description provided for @writeoffReasonBreakage.
  ///
  /// In ru, this message translates to:
  /// **'Бой'**
  String get writeoffReasonBreakage;

  /// No description provided for @writeoffReasonExpired.
  ///
  /// In ru, this message translates to:
  /// **'Просрочка'**
  String get writeoffReasonExpired;

  /// No description provided for @writeoffReasonDamage.
  ///
  /// In ru, this message translates to:
  /// **'Порча'**
  String get writeoffReasonDamage;

  /// No description provided for @writeoffReasonLoss.
  ///
  /// In ru, this message translates to:
  /// **'Утеря'**
  String get writeoffReasonLoss;

  /// No description provided for @writeoffReasonOther.
  ///
  /// In ru, this message translates to:
  /// **'Прочее'**
  String get writeoffReasonOther;

  /// No description provided for @writeoffCancelQuestion.
  ///
  /// In ru, this message translates to:
  /// **'Отменить списание?'**
  String get writeoffCancelQuestion;

  /// No description provided for @writeoffSaved.
  ///
  /// In ru, this message translates to:
  /// **'Списание сохранено'**
  String get writeoffSaved;

  /// No description provided for @settingsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Настройки'**
  String get settingsTitle;

  /// No description provided for @settingsPosInfo.
  ///
  /// In ru, this message translates to:
  /// **'Информация о кассе'**
  String get settingsPosInfo;

  /// No description provided for @settingsPosName.
  ///
  /// In ru, this message translates to:
  /// **'Название кассы'**
  String get settingsPosName;

  /// No description provided for @settingsCompany.
  ///
  /// In ru, this message translates to:
  /// **'Компания'**
  String get settingsCompany;

  /// No description provided for @settingsIin.
  ///
  /// In ru, this message translates to:
  /// **'ИИН/БИН'**
  String get settingsIin;

  /// No description provided for @settingsPosId.
  ///
  /// In ru, this message translates to:
  /// **'ID POS'**
  String get settingsPosId;

  /// No description provided for @settingsStoreId.
  ///
  /// In ru, this message translates to:
  /// **'ID магазина'**
  String get settingsStoreId;

  /// No description provided for @settingsNotSpecified.
  ///
  /// In ru, this message translates to:
  /// **'Не указано'**
  String get settingsNotSpecified;

  /// No description provided for @settingsAppVersion.
  ///
  /// In ru, this message translates to:
  /// **'Версия приложения'**
  String get settingsAppVersion;

  /// No description provided for @settingsVersion.
  ///
  /// In ru, this message translates to:
  /// **'Версия'**
  String get settingsVersion;

  /// No description provided for @settingsPlatform.
  ///
  /// In ru, this message translates to:
  /// **'Платформа'**
  String get settingsPlatform;

  /// No description provided for @settingsLanguage.
  ///
  /// In ru, this message translates to:
  /// **'Язык интерфейса'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageChanged.
  ///
  /// In ru, this message translates to:
  /// **'Язык изменён'**
  String get settingsLanguageChanged;

  /// No description provided for @settingsCurrency.
  ///
  /// In ru, this message translates to:
  /// **'Валюта'**
  String get settingsCurrency;

  /// No description provided for @settingsCurrencySymbol.
  ///
  /// In ru, this message translates to:
  /// **'Символ'**
  String get settingsCurrencySymbol;

  /// No description provided for @settingsCurrencyCode.
  ///
  /// In ru, this message translates to:
  /// **'Код'**
  String get settingsCurrencyCode;

  /// No description provided for @settingsCountry.
  ///
  /// In ru, this message translates to:
  /// **'Страна'**
  String get settingsCountry;

  /// No description provided for @settingsAdditional.
  ///
  /// In ru, this message translates to:
  /// **'Дополнительные настройки'**
  String get settingsAdditional;

  /// No description provided for @settingsTransport.
  ///
  /// In ru, this message translates to:
  /// **'Транспорт'**
  String get settingsTransport;

  /// No description provided for @settingsTransportDesc.
  ///
  /// In ru, this message translates to:
  /// **'Настройки синхронизации данных'**
  String get settingsTransportDesc;

  /// No description provided for @settingsPrinter.
  ///
  /// In ru, this message translates to:
  /// **'Принтер'**
  String get settingsPrinter;

  /// No description provided for @settingsPrinterDesc.
  ///
  /// In ru, this message translates to:
  /// **'Настройки печати чеков'**
  String get settingsPrinterDesc;

  /// No description provided for @settingsFiscal.
  ///
  /// In ru, this message translates to:
  /// **'Фискализация'**
  String get settingsFiscal;

  /// No description provided for @settingsFiscalDesc.
  ///
  /// In ru, this message translates to:
  /// **'WebKassa, ОФД, НДС'**
  String get settingsFiscalDesc;

  /// No description provided for @settingsTelegram.
  ///
  /// In ru, this message translates to:
  /// **'Telegram'**
  String get settingsTelegram;

  /// No description provided for @settingsTelegramDesc.
  ///
  /// In ru, this message translates to:
  /// **'Интеграция и каналы Telegram'**
  String get settingsTelegramDesc;

  /// No description provided for @settingsPermissions.
  ///
  /// In ru, this message translates to:
  /// **'Права доступа'**
  String get settingsPermissions;

  /// No description provided for @settingsPermissionsDesc.
  ///
  /// In ru, this message translates to:
  /// **'Разрешения для кассиров'**
  String get settingsPermissionsDesc;

  /// No description provided for @fiscalTitle.
  ///
  /// In ru, this message translates to:
  /// **'Фискализация'**
  String get fiscalTitle;

  /// No description provided for @fiscalOperator.
  ///
  /// In ru, this message translates to:
  /// **'Фискальный оператор'**
  String get fiscalOperator;

  /// No description provided for @fiscalWebkassa.
  ///
  /// In ru, this message translates to:
  /// **'Настройки WebKassa'**
  String get fiscalWebkassa;

  /// No description provided for @fiscalTaxpayer.
  ///
  /// In ru, this message translates to:
  /// **'Данные налогоплательщика'**
  String get fiscalTaxpayer;

  /// No description provided for @fiscalVatSettings.
  ///
  /// In ru, this message translates to:
  /// **'Настройки НДС'**
  String get fiscalVatSettings;

  /// No description provided for @fiscalVatPayer.
  ///
  /// In ru, this message translates to:
  /// **'Плательщик НДС'**
  String get fiscalVatPayer;

  /// No description provided for @fiscalPrintVat.
  ///
  /// In ru, this message translates to:
  /// **'Печатать НДС на чеке'**
  String get fiscalPrintVat;

  /// No description provided for @fiscalSaved.
  ///
  /// In ru, this message translates to:
  /// **'Настройки сохранены'**
  String get fiscalSaved;

  /// No description provided for @fiscalSaveError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка сохранения'**
  String get fiscalSaveError;

  /// No description provided for @printerSettingsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Настройки принтера'**
  String get printerSettingsTitle;

  /// No description provided for @printerConnectionType.
  ///
  /// In ru, this message translates to:
  /// **'Тип подключения'**
  String get printerConnectionType;

  /// No description provided for @printerAddress.
  ///
  /// In ru, this message translates to:
  /// **'Адрес принтера'**
  String get printerAddress;

  /// No description provided for @printerPaperWidth.
  ///
  /// In ru, this message translates to:
  /// **'Ширина бумаги'**
  String get printerPaperWidth;

  /// No description provided for @printerTesting.
  ///
  /// In ru, this message translates to:
  /// **'Тестирование'**
  String get printerTesting;

  /// No description provided for @printerReady.
  ///
  /// In ru, this message translates to:
  /// **'Готов'**
  String get printerReady;

  /// No description provided for @printerNotConnected.
  ///
  /// In ru, this message translates to:
  /// **'Не подключен'**
  String get printerNotConnected;

  /// No description provided for @printerPaperOut2.
  ///
  /// In ru, this message translates to:
  /// **'Нет бумаги'**
  String get printerPaperOut2;

  /// No description provided for @printerCoverOpen.
  ///
  /// In ru, this message translates to:
  /// **'Открыта крышка'**
  String get printerCoverOpen;

  /// No description provided for @printerPrinting.
  ///
  /// In ru, this message translates to:
  /// **'Печать...'**
  String get printerPrinting;

  /// No description provided for @printerCheckStatus.
  ///
  /// In ru, this message translates to:
  /// **'Проверка...'**
  String get printerCheckStatus;

  /// No description provided for @printerPrintSuccess.
  ///
  /// In ru, this message translates to:
  /// **'Печать успешна'**
  String get printerPrintSuccess;

  /// No description provided for @paymentNotFiscalized.
  ///
  /// In ru, this message translates to:
  /// **'Чек не фискализован — оплата проведена'**
  String get paymentNotFiscalized;

  /// No description provided for @paymentFiscalModuleAbsent.
  ///
  /// In ru, this message translates to:
  /// **'Модуль фискализации недоступен — чеки не фискализуются'**
  String get paymentFiscalModuleAbsent;

  /// No description provided for @cashDrawerOpenError.
  ///
  /// In ru, this message translates to:
  /// **'Денежный ящик не открылся'**
  String get cashDrawerOpenError;

  /// No description provided for @printerPrintError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка печати'**
  String get printerPrintError;

  /// No description provided for @printerCheckBtn.
  ///
  /// In ru, this message translates to:
  /// **'Проверить'**
  String get printerCheckBtn;

  /// No description provided for @printerTestReceipt.
  ///
  /// In ru, this message translates to:
  /// **'Тестовый чек'**
  String get printerTestReceipt;

  /// No description provided for @printerPort.
  ///
  /// In ru, this message translates to:
  /// **'Порт'**
  String get printerPort;

  /// No description provided for @cashOperationTitle.
  ///
  /// In ru, this message translates to:
  /// **'Кассовая операция'**
  String get cashOperationTitle;

  /// No description provided for @cashWithdrawal.
  ///
  /// In ru, this message translates to:
  /// **'Изъятие'**
  String get cashWithdrawal;

  /// No description provided for @cashCommentRequired.
  ///
  /// In ru, this message translates to:
  /// **'Комментарий *'**
  String get cashCommentRequired;

  /// No description provided for @cashCommentOptional.
  ///
  /// In ru, this message translates to:
  /// **'Комментарий'**
  String get cashCommentOptional;

  /// No description provided for @cashCommentHint.
  ///
  /// In ru, this message translates to:
  /// **'Введите комментарий...'**
  String get cashCommentHint;

  /// No description provided for @cashEnterAmountMsg.
  ///
  /// In ru, this message translates to:
  /// **'Введите сумму'**
  String get cashEnterAmountMsg;

  /// No description provided for @cashPositiveOnly.
  ///
  /// In ru, this message translates to:
  /// **'Сумма должна быть положительной'**
  String get cashPositiveOnly;

  /// No description provided for @cashInsufficient.
  ///
  /// In ru, this message translates to:
  /// **'Недостаточно денег в кассе'**
  String get cashInsufficient;

  /// No description provided for @cashInvalidAmount.
  ///
  /// In ru, this message translates to:
  /// **'Введите корректную сумму'**
  String get cashInvalidAmount;

  /// No description provided for @cashInDrawer.
  ///
  /// In ru, this message translates to:
  /// **'В кассе:'**
  String get cashInDrawer;

  /// No description provided for @telegramTitle.
  ///
  /// In ru, this message translates to:
  /// **'Настройки Telegram'**
  String get telegramTitle;

  /// No description provided for @telegramAuth.
  ///
  /// In ru, this message translates to:
  /// **'Авторизация'**
  String get telegramAuth;

  /// No description provided for @telegramSync.
  ///
  /// In ru, this message translates to:
  /// **'Синхронизация'**
  String get telegramSync;

  /// No description provided for @telegramNotifications.
  ///
  /// In ru, this message translates to:
  /// **'Включить уведомления'**
  String get telegramNotifications;

  /// No description provided for @telegramAutoSync.
  ///
  /// In ru, this message translates to:
  /// **'Автосинхронизация'**
  String get telegramAutoSync;

  /// No description provided for @telegramSyncData.
  ///
  /// In ru, this message translates to:
  /// **'Автоматически синхронизировать данные'**
  String get telegramSyncData;

  /// No description provided for @telegramSyncInterval.
  ///
  /// In ru, this message translates to:
  /// **'Интервал синхронизации'**
  String get telegramSyncInterval;

  /// No description provided for @telegramForceSync.
  ///
  /// In ru, this message translates to:
  /// **'Принудительная синхронизация'**
  String get telegramForceSync;

  /// No description provided for @telegramFullSync.
  ///
  /// In ru, this message translates to:
  /// **'Полная синхронизация'**
  String get telegramFullSync;

  /// No description provided for @telegramRecreateChannels.
  ///
  /// In ru, this message translates to:
  /// **'Пересоздать каналы'**
  String get telegramRecreateChannels;

  /// No description provided for @telegramLogout.
  ///
  /// In ru, this message translates to:
  /// **'Выйти из Telegram'**
  String get telegramLogout;

  /// No description provided for @telegramSyncComplete.
  ///
  /// In ru, this message translates to:
  /// **'Синхронизация завершена'**
  String get telegramSyncComplete;

  /// No description provided for @telegramSyncError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка синхронизации'**
  String get telegramSyncError;

  /// No description provided for @telegramLogoutComplete.
  ///
  /// In ru, this message translates to:
  /// **'Выход выполнен'**
  String get telegramLogoutComplete;

  /// No description provided for @chatTitle.
  ///
  /// In ru, this message translates to:
  /// **'Чат сотрудников'**
  String get chatTitle;

  /// No description provided for @chatParticipants.
  ///
  /// In ru, this message translates to:
  /// **'{count} участников'**
  String chatParticipants(int count);

  /// No description provided for @chatConnected.
  ///
  /// In ru, this message translates to:
  /// **'Подключено'**
  String get chatConnected;

  /// No description provided for @chatDisconnected.
  ///
  /// In ru, this message translates to:
  /// **'Нет соединения'**
  String get chatDisconnected;

  /// No description provided for @chatNoMessages.
  ///
  /// In ru, this message translates to:
  /// **'Нет сообщений'**
  String get chatNoMessages;

  /// No description provided for @chatStartConversation.
  ///
  /// In ru, this message translates to:
  /// **'Начните общение с командой'**
  String get chatStartConversation;

  /// No description provided for @chatMessageHint.
  ///
  /// In ru, this message translates to:
  /// **'Сообщение...'**
  String get chatMessageHint;

  /// No description provided for @chatSearch.
  ///
  /// In ru, this message translates to:
  /// **'Поиск'**
  String get chatSearch;

  /// No description provided for @chatSearchHint.
  ///
  /// In ru, this message translates to:
  /// **'Введите текст для поиска...'**
  String get chatSearchHint;

  /// No description provided for @chatMembers.
  ///
  /// In ru, this message translates to:
  /// **'Участники'**
  String get chatMembers;

  /// No description provided for @chatLinkTelegram.
  ///
  /// In ru, this message translates to:
  /// **'Привязать Telegram'**
  String get chatLinkTelegram;

  /// No description provided for @chatCopied.
  ///
  /// In ru, this message translates to:
  /// **'Скопировано'**
  String get chatCopied;

  /// No description provided for @chatReply.
  ///
  /// In ru, this message translates to:
  /// **'Ответить'**
  String get chatReply;

  /// No description provided for @chatCopy.
  ///
  /// In ru, this message translates to:
  /// **'Копировать'**
  String get chatCopy;

  /// No description provided for @chatDeleteMsg.
  ///
  /// In ru, this message translates to:
  /// **'Удалить сообщение?'**
  String get chatDeleteMsg;

  /// No description provided for @chatDeleteConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Сообщение будет удалено для всех участников чата.'**
  String get chatDeleteConfirm;

  /// No description provided for @chatPhoto.
  ///
  /// In ru, this message translates to:
  /// **'Фото'**
  String get chatPhoto;

  /// No description provided for @chatDocument.
  ///
  /// In ru, this message translates to:
  /// **'Документ'**
  String get chatDocument;

  /// No description provided for @chatLocation.
  ///
  /// In ru, this message translates to:
  /// **'Местоположение'**
  String get chatLocation;

  /// No description provided for @chatCamera.
  ///
  /// In ru, this message translates to:
  /// **'Камера'**
  String get chatCamera;

  /// No description provided for @chatGallery.
  ///
  /// In ru, this message translates to:
  /// **'Галерея'**
  String get chatGallery;

  /// No description provided for @chatSelectSource.
  ///
  /// In ru, this message translates to:
  /// **'Выберите источник'**
  String get chatSelectSource;

  /// No description provided for @updateAvailable.
  ///
  /// In ru, this message translates to:
  /// **'Доступно обновление'**
  String get updateAvailable;

  /// No description provided for @updateInProgress.
  ///
  /// In ru, this message translates to:
  /// **'Обновление...'**
  String get updateInProgress;

  /// No description provided for @updateAutoIn.
  ///
  /// In ru, this message translates to:
  /// **'Автоматическое обновление через {seconds} сек'**
  String updateAutoIn(int seconds);

  /// No description provided for @updateNowBtn.
  ///
  /// In ru, this message translates to:
  /// **'Обновить сейчас'**
  String get updateNowBtn;

  /// No description provided for @updateLater.
  ///
  /// In ru, this message translates to:
  /// **'Позже'**
  String get updateLater;

  /// No description provided for @updateSkip.
  ///
  /// In ru, this message translates to:
  /// **'Пропустить'**
  String get updateSkip;

  /// No description provided for @updateBtn.
  ///
  /// In ru, this message translates to:
  /// **'Обновить'**
  String get updateBtn;

  /// No description provided for @storageWarningTitle.
  ///
  /// In ru, this message translates to:
  /// **'Мало места на диске'**
  String get storageWarningTitle;

  /// No description provided for @storageWarningMsg.
  ///
  /// In ru, this message translates to:
  /// **'Для стабильной работы кассы рекомендуется освободить минимум 2 GB.'**
  String get storageWarningMsg;

  /// No description provided for @storageUnderstood.
  ///
  /// In ru, this message translates to:
  /// **'Понятно'**
  String get storageUnderstood;

  /// No description provided for @errorCritical.
  ///
  /// In ru, this message translates to:
  /// **'Критическая ошибка'**
  String get errorCritical;

  /// No description provided for @errorAppProblem.
  ///
  /// In ru, this message translates to:
  /// **'Приложение столкнулось с проблемой'**
  String get errorAppProblem;

  /// No description provided for @errorDescription.
  ///
  /// In ru, this message translates to:
  /// **'Описание ошибки:'**
  String get errorDescription;

  /// No description provided for @errorTechnical.
  ///
  /// In ru, this message translates to:
  /// **'Технические детали'**
  String get errorTechnical;

  /// No description provided for @errorRetry.
  ///
  /// In ru, this message translates to:
  /// **'Повторить'**
  String get errorRetry;

  /// No description provided for @errorOpenFolder.
  ///
  /// In ru, this message translates to:
  /// **'Открыть папку'**
  String get errorOpenFolder;

  /// No description provided for @errorOtherVersion.
  ///
  /// In ru, this message translates to:
  /// **'Другая версия'**
  String get errorOtherVersion;

  /// No description provided for @errorExit.
  ///
  /// In ru, this message translates to:
  /// **'Выйти'**
  String get errorExit;

  /// No description provided for @switchOn.
  ///
  /// In ru, this message translates to:
  /// **'Вкл'**
  String get switchOn;

  /// No description provided for @switchOff.
  ///
  /// In ru, this message translates to:
  /// **'Выкл'**
  String get switchOff;

  /// No description provided for @keyboardSpace.
  ///
  /// In ru, this message translates to:
  /// **'Пробел'**
  String get keyboardSpace;

  /// No description provided for @keyboardHide.
  ///
  /// In ru, this message translates to:
  /// **'Скрыть клавиатуру'**
  String get keyboardHide;

  /// No description provided for @keyboardShow.
  ///
  /// In ru, this message translates to:
  /// **'Показать клавиатуру'**
  String get keyboardShow;

  /// No description provided for @commentReceipt.
  ///
  /// In ru, this message translates to:
  /// **'Комментарий к чеку'**
  String get commentReceipt;

  /// No description provided for @commentReceiptHint.
  ///
  /// In ru, this message translates to:
  /// **'Введите комментарий...'**
  String get commentReceiptHint;

  /// No description provided for @productNameLabel.
  ///
  /// In ru, this message translates to:
  /// **'Название товара'**
  String get productNameLabel;

  /// No description provided for @productNameHint.
  ///
  /// In ru, this message translates to:
  /// **'Введите название...'**
  String get productNameHint;

  /// No description provided for @nothingFound.
  ///
  /// In ru, this message translates to:
  /// **'Ничего не найдено'**
  String get nothingFound;

  /// No description provided for @datePlaceholder.
  ///
  /// In ru, this message translates to:
  /// **'ДД.ММ.ГГГГ'**
  String get datePlaceholder;

  /// No description provided for @timePlaceholder.
  ///
  /// In ru, this message translates to:
  /// **'ЧЧ:ММ'**
  String get timePlaceholder;

  /// No description provided for @dateTimePlaceholder.
  ///
  /// In ru, this message translates to:
  /// **'ДД.ММ.ГГГГ ЧЧ:ММ'**
  String get dateTimePlaceholder;

  /// No description provided for @selectPeriod.
  ///
  /// In ru, this message translates to:
  /// **'Выберите период'**
  String get selectPeriod;

  /// No description provided for @bonusProgram.
  ///
  /// In ru, this message translates to:
  /// **'Бонусная программа'**
  String get bonusProgram;

  /// No description provided for @enterPhone.
  ///
  /// In ru, this message translates to:
  /// **'Введите номер телефона клиента'**
  String get enterPhone;

  /// No description provided for @enterSmsCode.
  ///
  /// In ru, this message translates to:
  /// **'Введите код из SMS'**
  String get enterSmsCode;

  /// No description provided for @resendIn.
  ///
  /// In ru, this message translates to:
  /// **'Повторная отправка через {seconds} сек'**
  String resendIn(int seconds);

  /// No description provided for @resendCode.
  ///
  /// In ru, this message translates to:
  /// **'Отправить код повторно'**
  String get resendCode;

  /// No description provided for @availableBonuses.
  ///
  /// In ru, this message translates to:
  /// **'Доступно бонусов:'**
  String get availableBonuses;

  /// No description provided for @useBonuses.
  ///
  /// In ru, this message translates to:
  /// **'Списать бонусов'**
  String get useBonuses;

  /// No description provided for @deferredSales.
  ///
  /// In ru, this message translates to:
  /// **'Отложенные продажи'**
  String get deferredSales;

  /// No description provided for @noDeferredSales.
  ///
  /// In ru, this message translates to:
  /// **'Нет отложенных продаж'**
  String get noDeferredSales;

  /// No description provided for @fiscalErrors.
  ///
  /// In ru, this message translates to:
  /// **'Ошибки фискализации'**
  String get fiscalErrors;

  /// No description provided for @selectAllErrors.
  ///
  /// In ru, this message translates to:
  /// **'Выбрать все'**
  String get selectAllErrors;

  /// No description provided for @retrySelected.
  ///
  /// In ru, this message translates to:
  /// **'Повторить'**
  String get retrySelected;

  /// No description provided for @receiptNo.
  ///
  /// In ru, this message translates to:
  /// **'Чек #{number}'**
  String receiptNo(String number);

  /// No description provided for @dontAskAgain.
  ///
  /// In ru, this message translates to:
  /// **'Не спрашивать снова'**
  String get dontAskAgain;

  /// No description provided for @deleteTitle.
  ///
  /// In ru, this message translates to:
  /// **'Удаление'**
  String get deleteTitle;

  /// No description provided for @deleteItemConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Вы уверены, что хотите удалить \"{name}\"?'**
  String deleteItemConfirm(String name);

  /// No description provided for @exitTitle.
  ///
  /// In ru, this message translates to:
  /// **'Выход'**
  String get exitTitle;

  /// No description provided for @exitConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Вы уверены, что хотите выйти?'**
  String get exitConfirm;

  /// No description provided for @exitBtn.
  ///
  /// In ru, this message translates to:
  /// **'Выйти'**
  String get exitBtn;

  /// No description provided for @valueCannotBeNegative.
  ///
  /// In ru, this message translates to:
  /// **'Значение не может быть отрицательным'**
  String get valueCannotBeNegative;

  /// No description provided for @maxPercent.
  ///
  /// In ru, this message translates to:
  /// **'Максимум {percent}%'**
  String maxPercent(String percent);

  /// No description provided for @maxAmount.
  ///
  /// In ru, this message translates to:
  /// **'Максимум {amount}'**
  String maxAmount(String amount);

  /// No description provided for @enterValidNumber.
  ///
  /// In ru, this message translates to:
  /// **'Введите корректное число'**
  String get enterValidNumber;

  /// No description provided for @discountAmount.
  ///
  /// In ru, this message translates to:
  /// **'Сумма скидки:'**
  String get discountAmount;

  /// No description provided for @discountLimitPercent.
  ///
  /// In ru, this message translates to:
  /// **'Доступно до {percent} % — {source}'**
  String discountLimitPercent(String percent, String source);

  /// No description provided for @discountLimitAmount.
  ///
  /// In ru, this message translates to:
  /// **'Доступно до {amount} — {source}'**
  String discountLimitAmount(String amount, String source);

  /// No description provided for @discountApprovalAbove.
  ///
  /// In ru, this message translates to:
  /// **'Выше {percent} % нужно подтверждение старшего'**
  String discountApprovalAbove(String percent);

  /// No description provided for @sumLabel.
  ///
  /// In ru, this message translates to:
  /// **'Сумма'**
  String get sumLabel;

  /// No description provided for @enterAmount.
  ///
  /// In ru, this message translates to:
  /// **'Введите сумму'**
  String get enterAmount;

  /// No description provided for @amountMustBePositive.
  ///
  /// In ru, this message translates to:
  /// **'Сумма должна быть положительной'**
  String get amountMustBePositive;

  /// No description provided for @notEnoughCashInDrawer.
  ///
  /// In ru, this message translates to:
  /// **'Недостаточно денег в кассе'**
  String get notEnoughCashInDrawer;

  /// No description provided for @enterValidAmount.
  ///
  /// In ru, this message translates to:
  /// **'Введите корректную сумму'**
  String get enterValidAmount;

  /// No description provided for @inDrawer.
  ///
  /// In ru, this message translates to:
  /// **'В кассе:'**
  String get inDrawer;

  /// No description provided for @commentOptional.
  ///
  /// In ru, this message translates to:
  /// **'Комментарий (необязательно)'**
  String get commentOptional;

  /// No description provided for @operationReason.
  ///
  /// In ru, this message translates to:
  /// **'Причина операции...'**
  String get operationReason;

  /// No description provided for @positions.
  ///
  /// In ru, this message translates to:
  /// **'позиций'**
  String get positions;

  /// No description provided for @enterWeight.
  ///
  /// In ru, this message translates to:
  /// **'Введите вес'**
  String get enterWeight;

  /// No description provided for @weightMustBePositive.
  ///
  /// In ru, this message translates to:
  /// **'Вес должен быть положительным'**
  String get weightMustBePositive;

  /// No description provided for @maxWeightValue.
  ///
  /// In ru, this message translates to:
  /// **'Максимум {max} {unit}'**
  String maxWeightValue(String max, String unit);

  /// No description provided for @unitPcs.
  ///
  /// In ru, this message translates to:
  /// **'шт'**
  String get unitPcs;

  /// No description provided for @unitKg.
  ///
  /// In ru, this message translates to:
  /// **'кг'**
  String get unitKg;

  /// No description provided for @lowStorageTooltip.
  ///
  /// In ru, this message translates to:
  /// **'Мало места: {gb} GB'**
  String lowStorageTooltip(String gb);

  /// No description provided for @storageFree.
  ///
  /// In ru, this message translates to:
  /// **'Свободно: {gb} GB'**
  String storageFree(String gb);

  /// No description provided for @storageRecommendation.
  ///
  /// In ru, this message translates to:
  /// **'Для стабильной работы кассы рекомендуется иметь минимум 2 GB свободного места.\n\nПожалуйста, освободите место на диске или обратитесь к администратору.'**
  String get storageRecommendation;

  /// No description provided for @lowStorageBanner.
  ///
  /// In ru, this message translates to:
  /// **'Мало свободного места: {gb} GB. Рекомендуется освободить минимум 2 GB для стабильной работы.'**
  String lowStorageBanner(String gb);

  /// No description provided for @lowStorageTooltipShort.
  ///
  /// In ru, this message translates to:
  /// **'Мало места на диске: {gb} GB'**
  String lowStorageTooltipShort(String gb);

  /// No description provided for @cashier.
  ///
  /// In ru, this message translates to:
  /// **'Кассир:'**
  String get cashier;

  /// No description provided for @buyer.
  ///
  /// In ru, this message translates to:
  /// **'Покупатель:'**
  String get buyer;

  /// No description provided for @receiptHeader.
  ///
  /// In ru, this message translates to:
  /// **'ЧЕК #{number}'**
  String receiptHeader(int number);

  /// No description provided for @receiptDiscountItem.
  ///
  /// In ru, this message translates to:
  /// **'Скидка:'**
  String get receiptDiscountItem;

  /// No description provided for @receiptSubtotalLabel.
  ///
  /// In ru, this message translates to:
  /// **'Подитого'**
  String get receiptSubtotalLabel;

  /// No description provided for @receiptPayment.
  ///
  /// In ru, this message translates to:
  /// **'Оплата:'**
  String get receiptPayment;

  /// No description provided for @fiscalMark.
  ///
  /// In ru, this message translates to:
  /// **'ФП:'**
  String get fiscalMark;

  /// No description provided for @remainingStock.
  ///
  /// In ru, this message translates to:
  /// **'Ост: {qty}'**
  String remainingStock(String qty);

  /// No description provided for @tableHeaderName.
  ///
  /// In ru, this message translates to:
  /// **'Название'**
  String get tableHeaderName;

  /// No description provided for @tableHeaderPrice.
  ///
  /// In ru, this message translates to:
  /// **'Цена'**
  String get tableHeaderPrice;

  /// No description provided for @tableHeaderQty.
  ///
  /// In ru, this message translates to:
  /// **'Кол-во'**
  String get tableHeaderQty;

  /// No description provided for @tableHeaderTotal.
  ///
  /// In ru, this message translates to:
  /// **'Итого'**
  String get tableHeaderTotal;

  /// No description provided for @emptyReceipt.
  ///
  /// In ru, this message translates to:
  /// **'Чек пуст'**
  String get emptyReceipt;

  /// No description provided for @addProductsViaSearch.
  ///
  /// In ru, this message translates to:
  /// **'Добавьте товары через поиск\nили сканируйте штрих-код'**
  String get addProductsViaSearch;

  /// No description provided for @addProductsViaSearchShort.
  ///
  /// In ru, this message translates to:
  /// **'Добавьте товары через поиск'**
  String get addProductsViaSearchShort;

  /// No description provided for @priceLabel.
  ///
  /// In ru, this message translates to:
  /// **'Цена'**
  String get priceLabel;

  /// No description provided for @receiptTotalLabel.
  ///
  /// In ru, this message translates to:
  /// **'Итого по чеку'**
  String get receiptTotalLabel;

  /// No description provided for @positionsLabel.
  ///
  /// In ru, this message translates to:
  /// **'Позиций'**
  String get positionsLabel;

  /// No description provided for @toPayLabel.
  ///
  /// In ru, this message translates to:
  /// **'К ОПЛАТЕ'**
  String get toPayLabel;

  /// No description provided for @payBtn.
  ///
  /// In ru, this message translates to:
  /// **'ОПЛАТИТЬ'**
  String get payBtn;

  /// No description provided for @totalLabel.
  ///
  /// In ru, this message translates to:
  /// **'Итого:'**
  String get totalLabel;

  /// No description provided for @posAndQty.
  ///
  /// In ru, this message translates to:
  /// **'{positions} поз. / {qty} шт.'**
  String posAndQty(int positions, String qty);

  /// No description provided for @modeRetail.
  ///
  /// In ru, this message translates to:
  /// **'Розница'**
  String get modeRetail;

  /// No description provided for @modeWholesale.
  ///
  /// In ru, this message translates to:
  /// **'ОПТ'**
  String get modeWholesale;

  /// No description provided for @quickProducts.
  ///
  /// In ru, this message translates to:
  /// **'Быстрые товары'**
  String get quickProducts;

  /// No description provided for @editProduct.
  ///
  /// In ru, this message translates to:
  /// **'Редактирование'**
  String get editProduct;

  /// No description provided for @labelComment.
  ///
  /// In ru, this message translates to:
  /// **'Комментарий'**
  String get labelComment;

  /// No description provided for @selectPackage.
  ///
  /// In ru, this message translates to:
  /// **'Выберите фасовку'**
  String get selectPackage;

  /// No description provided for @packageQty.
  ///
  /// In ru, this message translates to:
  /// **'{qty} шт'**
  String packageQty(String qty);

  /// No description provided for @allBreadcrumb.
  ///
  /// In ru, this message translates to:
  /// **'Все'**
  String get allBreadcrumb;

  /// No description provided for @maxBonusPercent.
  ///
  /// In ru, this message translates to:
  /// **'Можно списать до {percent}% от суммы чека'**
  String maxBonusPercent(int percent);

  /// No description provided for @insufficientBonuses.
  ///
  /// In ru, this message translates to:
  /// **'Недостаточно бонусов'**
  String get insufficientBonuses;

  /// No description provided for @enterValidPhone.
  ///
  /// In ru, this message translates to:
  /// **'Введите корректный номер'**
  String get enterValidPhone;

  /// No description provided for @errorsCount.
  ///
  /// In ru, this message translates to:
  /// **'{count} ошибок'**
  String errorsCount(int count);

  /// No description provided for @selectAllCount.
  ///
  /// In ru, this message translates to:
  /// **'Выбрать все ({count})'**
  String selectAllCount(int count);

  /// No description provided for @retryCount.
  ///
  /// In ru, this message translates to:
  /// **'Повторить ({count})'**
  String retryCount(int count);

  /// No description provided for @receiptHash.
  ///
  /// In ru, this message translates to:
  /// **'Чек #{number}'**
  String receiptHash(int number);

  /// No description provided for @enterIntegerNumber.
  ///
  /// In ru, this message translates to:
  /// **'Введите целое число'**
  String get enterIntegerNumber;

  /// No description provided for @enterDigits.
  ///
  /// In ru, this message translates to:
  /// **'Введите {length} цифры'**
  String enterDigits(int length);

  /// No description provided for @drawerPrimary.
  ///
  /// In ru, this message translates to:
  /// **'Основное'**
  String get drawerPrimary;

  /// No description provided for @drawerSecondary.
  ///
  /// In ru, this message translates to:
  /// **'Дополнительно'**
  String get drawerSecondary;

  /// No description provided for @tooltipMore.
  ///
  /// In ru, this message translates to:
  /// **'Ещё'**
  String get tooltipMore;

  /// No description provided for @statusOnline.
  ///
  /// In ru, this message translates to:
  /// **'Online'**
  String get statusOnline;

  /// No description provided for @statusOffline.
  ///
  /// In ru, this message translates to:
  /// **'Offline'**
  String get statusOffline;

  /// No description provided for @statusSyncing.
  ///
  /// In ru, this message translates to:
  /// **'Sync...'**
  String get statusSyncing;

  /// No description provided for @thankYouForPurchase.
  ///
  /// In ru, this message translates to:
  /// **'Спасибо за покупку!'**
  String get thankYouForPurchase;

  /// No description provided for @searchProductHint.
  ///
  /// In ru, this message translates to:
  /// **'Поиск товара (название или штрих-код)'**
  String get searchProductHint;

  /// No description provided for @actionDefer.
  ///
  /// In ru, this message translates to:
  /// **'Отложить'**
  String get actionDefer;

  /// No description provided for @actionDeferredList.
  ///
  /// In ru, this message translates to:
  /// **'Отложенные'**
  String get actionDeferredList;

  /// No description provided for @actionMark.
  ///
  /// In ru, this message translates to:
  /// **'Маркировка'**
  String get actionMark;

  /// No description provided for @actionWeigh.
  ///
  /// In ru, this message translates to:
  /// **'Весы'**
  String get actionWeigh;

  /// No description provided for @actionPrintLabel.
  ///
  /// In ru, this message translates to:
  /// **'Ценник'**
  String get actionPrintLabel;

  /// No description provided for @supplierRepayTitle.
  ///
  /// In ru, this message translates to:
  /// **'Погасить долг поставщику'**
  String get supplierRepayTitle;

  /// No description provided for @supplierRepayCurrentDebt.
  ///
  /// In ru, this message translates to:
  /// **'Текущий долг: {amount}'**
  String supplierRepayCurrentDebt(String amount);

  /// No description provided for @supplierRepayNoDebt.
  ///
  /// In ru, this message translates to:
  /// **'Долга перед поставщиком нет'**
  String get supplierRepayNoDebt;

  /// No description provided for @supplierRepayAmountLabel.
  ///
  /// In ru, this message translates to:
  /// **'Сумма оплаты'**
  String get supplierRepayAmountLabel;

  /// No description provided for @supplierRepayAmountError.
  ///
  /// In ru, this message translates to:
  /// **'Введите сумму больше 0'**
  String get supplierRepayAmountError;

  /// No description provided for @supplierRepaySubmit.
  ///
  /// In ru, this message translates to:
  /// **'Оплатить поставщику'**
  String get supplierRepaySubmit;

  /// No description provided for @supplierRepayDone.
  ///
  /// In ru, this message translates to:
  /// **'Оплата поставщику проведена'**
  String get supplierRepayDone;

  /// No description provided for @supplierRepayError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка проведения оплаты'**
  String get supplierRepayError;

  /// No description provided for @actionIncrease.
  ///
  /// In ru, this message translates to:
  /// **'Увеличить'**
  String get actionIncrease;

  /// No description provided for @actionDecrease.
  ///
  /// In ru, this message translates to:
  /// **'Уменьшить'**
  String get actionDecrease;

  /// No description provided for @restaurantSettings.
  ///
  /// In ru, this message translates to:
  /// **'Режим ресторана'**
  String get restaurantSettings;

  /// No description provided for @restaurantSettingsDesc.
  ///
  /// In ru, this message translates to:
  /// **'Столы, зоны, сервисный сбор'**
  String get restaurantSettingsDesc;

  /// No description provided for @restaurantOperatingMode.
  ///
  /// In ru, this message translates to:
  /// **'Режим работы'**
  String get restaurantOperatingMode;

  /// No description provided for @restaurantModeRetail.
  ///
  /// In ru, this message translates to:
  /// **'Розничная торговля'**
  String get restaurantModeRetail;

  /// No description provided for @restaurantModeRetailDesc.
  ///
  /// In ru, this message translates to:
  /// **'Стандартный POS для магазинов'**
  String get restaurantModeRetailDesc;

  /// No description provided for @restaurantModeRestaurant.
  ///
  /// In ru, this message translates to:
  /// **'Ресторан'**
  String get restaurantModeRestaurant;

  /// No description provided for @restaurantModeRestaurantDesc.
  ///
  /// In ru, this message translates to:
  /// **'Столы, заказы, сервисный сбор'**
  String get restaurantModeRestaurantDesc;

  /// No description provided for @restaurantModeService.
  ///
  /// In ru, this message translates to:
  /// **'Сервис'**
  String get restaurantModeService;

  /// No description provided for @restaurantModeServiceDesc.
  ///
  /// In ru, this message translates to:
  /// **'Приём заявок, очередь'**
  String get restaurantModeServiceDesc;

  /// No description provided for @restaurantZoneManagement.
  ///
  /// In ru, this message translates to:
  /// **'Управление зонами'**
  String get restaurantZoneManagement;

  /// No description provided for @restaurantZoneAdd.
  ///
  /// In ru, this message translates to:
  /// **'Добавить зону'**
  String get restaurantZoneAdd;

  /// No description provided for @restaurantZoneRename.
  ///
  /// In ru, this message translates to:
  /// **'Переименовать'**
  String get restaurantZoneRename;

  /// No description provided for @restaurantZonePresets.
  ///
  /// In ru, this message translates to:
  /// **'Предустановки'**
  String get restaurantZonePresets;

  /// No description provided for @restaurantZoneHall.
  ///
  /// In ru, this message translates to:
  /// **'Зал'**
  String get restaurantZoneHall;

  /// No description provided for @restaurantZoneTerrace.
  ///
  /// In ru, this message translates to:
  /// **'Терраса'**
  String get restaurantZoneTerrace;

  /// No description provided for @restaurantZoneVip.
  ///
  /// In ru, this message translates to:
  /// **'VIP'**
  String get restaurantZoneVip;

  /// No description provided for @restaurantZoneBar.
  ///
  /// In ru, this message translates to:
  /// **'Бар'**
  String get restaurantZoneBar;

  /// No description provided for @restaurantZoneBooth.
  ///
  /// In ru, this message translates to:
  /// **'Кабинка'**
  String get restaurantZoneBooth;

  /// No description provided for @restaurantZoneKaraoke.
  ///
  /// In ru, this message translates to:
  /// **'Караоке'**
  String get restaurantZoneKaraoke;

  /// No description provided for @restaurantZoneVeranda.
  ///
  /// In ru, this message translates to:
  /// **'Веранда'**
  String get restaurantZoneVeranda;

  /// No description provided for @restaurantZonePrivate.
  ///
  /// In ru, this message translates to:
  /// **'Приватная комната'**
  String get restaurantZonePrivate;

  /// No description provided for @restaurantTableManagement.
  ///
  /// In ru, this message translates to:
  /// **'Управление столами'**
  String get restaurantTableManagement;

  /// No description provided for @restaurantTableAdd.
  ///
  /// In ru, this message translates to:
  /// **'Добавить стол'**
  String get restaurantTableAdd;

  /// No description provided for @restaurantTableEdit.
  ///
  /// In ru, this message translates to:
  /// **'Редактировать стол'**
  String get restaurantTableEdit;

  /// No description provided for @restaurantTableName.
  ///
  /// In ru, this message translates to:
  /// **'Название стола'**
  String get restaurantTableName;

  /// No description provided for @restaurantTableCapacity.
  ///
  /// In ru, this message translates to:
  /// **'Вместимость'**
  String get restaurantTableCapacity;

  /// No description provided for @restaurantTableZone.
  ///
  /// In ru, this message translates to:
  /// **'Зона'**
  String get restaurantTableZone;

  /// No description provided for @restaurantTableSortOrder.
  ///
  /// In ru, this message translates to:
  /// **'Порядок'**
  String get restaurantTableSortOrder;

  /// No description provided for @restaurantTableDeactivate.
  ///
  /// In ru, this message translates to:
  /// **'Деактивировать стол'**
  String get restaurantTableDeactivate;

  /// No description provided for @restaurantTableDeactivateConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Деактивировать стол «{name}»?'**
  String restaurantTableDeactivateConfirm(String name);

  /// No description provided for @restaurantServiceCharge.
  ///
  /// In ru, this message translates to:
  /// **'Сервисный сбор'**
  String get restaurantServiceCharge;

  /// No description provided for @restaurantServiceChargeEnabled.
  ///
  /// In ru, this message translates to:
  /// **'Включить сервисный сбор'**
  String get restaurantServiceChargeEnabled;

  /// No description provided for @restaurantServiceChargePercent.
  ///
  /// In ru, this message translates to:
  /// **'Процент сервисного сбора'**
  String get restaurantServiceChargePercent;

  /// No description provided for @restaurantTableFree.
  ///
  /// In ru, this message translates to:
  /// **'Свободен'**
  String get restaurantTableFree;

  /// No description provided for @restaurantTableOccupied.
  ///
  /// In ru, this message translates to:
  /// **'Занят'**
  String get restaurantTableOccupied;

  /// No description provided for @restaurantTableReserved.
  ///
  /// In ru, this message translates to:
  /// **'Забронирован'**
  String get restaurantTableReserved;

  /// No description provided for @restaurantTableDirty.
  ///
  /// In ru, this message translates to:
  /// **'Убрать'**
  String get restaurantTableDirty;

  /// No description provided for @restaurantOrderDineIn.
  ///
  /// In ru, this message translates to:
  /// **'В зале'**
  String get restaurantOrderDineIn;

  /// No description provided for @restaurantOrderTakeout.
  ///
  /// In ru, this message translates to:
  /// **'Навынос'**
  String get restaurantOrderTakeout;

  /// No description provided for @restaurantOrderDelivery.
  ///
  /// In ru, this message translates to:
  /// **'Доставка'**
  String get restaurantOrderDelivery;

  /// No description provided for @restaurantAllZones.
  ///
  /// In ru, this message translates to:
  /// **'Все зоны'**
  String get restaurantAllZones;

  /// No description provided for @restaurantNoTables.
  ///
  /// In ru, this message translates to:
  /// **'Нет столов'**
  String get restaurantNoTables;

  /// No description provided for @restaurantNoTablesHint.
  ///
  /// In ru, this message translates to:
  /// **'Добавьте столы в настройках ресторана'**
  String get restaurantNoTablesHint;

  /// No description provided for @restaurantGoToSettings.
  ///
  /// In ru, this message translates to:
  /// **'Перейти в настройки'**
  String get restaurantGoToSettings;

  /// No description provided for @restaurantOrdersEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Нет активных заказов'**
  String get restaurantOrdersEmpty;

  /// No description provided for @restaurantOrderItems.
  ///
  /// In ru, this message translates to:
  /// **'{count} позиций'**
  String restaurantOrderItems(int count);

  /// No description provided for @restaurantOrderGuests.
  ///
  /// In ru, this message translates to:
  /// **'Гостей: {count}'**
  String restaurantOrderGuests(int count);

  /// No description provided for @restaurantOrderWaiter.
  ///
  /// In ru, this message translates to:
  /// **'Официант: {name}'**
  String restaurantOrderWaiter(String name);

  /// No description provided for @restaurantOrderElapsed.
  ///
  /// In ru, this message translates to:
  /// **'{minutes} мин'**
  String restaurantOrderElapsed(int minutes);

  /// No description provided for @restaurantNoOrder.
  ///
  /// In ru, this message translates to:
  /// **'Нет активного заказа'**
  String get restaurantNoOrder;

  /// No description provided for @restaurantOpenOrder.
  ///
  /// In ru, this message translates to:
  /// **'Открыть заказ'**
  String get restaurantOpenOrder;

  /// No description provided for @restaurantCloseOrder.
  ///
  /// In ru, this message translates to:
  /// **'Закрыть заказ'**
  String get restaurantCloseOrder;

  /// No description provided for @restaurantAddItems.
  ///
  /// In ru, this message translates to:
  /// **'Добавить позиции'**
  String get restaurantAddItems;

  /// No description provided for @restaurantGoToPayment.
  ///
  /// In ru, this message translates to:
  /// **'К оплате'**
  String get restaurantGoToPayment;

  /// No description provided for @restaurantTransfer.
  ///
  /// In ru, this message translates to:
  /// **'Перенести'**
  String get restaurantTransfer;

  /// No description provided for @restaurantSplitBill.
  ///
  /// In ru, this message translates to:
  /// **'Разделить'**
  String get restaurantSplitBill;

  /// No description provided for @restaurantChangeStatus.
  ///
  /// In ru, this message translates to:
  /// **'Изменить статус'**
  String get restaurantChangeStatus;

  /// No description provided for @restaurantSetFree.
  ///
  /// In ru, this message translates to:
  /// **'Свободен'**
  String get restaurantSetFree;

  /// No description provided for @restaurantSetReserved.
  ///
  /// In ru, this message translates to:
  /// **'Забронировать'**
  String get restaurantSetReserved;

  /// No description provided for @restaurantSetDirty.
  ///
  /// In ru, this message translates to:
  /// **'Требует уборки'**
  String get restaurantSetDirty;

  /// No description provided for @restaurantCreateOrder.
  ///
  /// In ru, this message translates to:
  /// **'Новый заказ'**
  String get restaurantCreateOrder;

  /// No description provided for @restaurantPartySize.
  ///
  /// In ru, this message translates to:
  /// **'Количество гостей'**
  String get restaurantPartySize;

  /// No description provided for @restaurantOrderType.
  ///
  /// In ru, this message translates to:
  /// **'Тип заказа'**
  String get restaurantOrderType;

  /// No description provided for @restaurantWaiter.
  ///
  /// In ru, this message translates to:
  /// **'Официант'**
  String get restaurantWaiter;

  /// No description provided for @restaurantNote.
  ///
  /// In ru, this message translates to:
  /// **'Примечание'**
  String get restaurantNote;

  /// No description provided for @restaurantDeliveryAddress.
  ///
  /// In ru, this message translates to:
  /// **'Адрес доставки'**
  String get restaurantDeliveryAddress;

  /// No description provided for @restaurantDeliveryPhone.
  ///
  /// In ru, this message translates to:
  /// **'Телефон'**
  String get restaurantDeliveryPhone;

  /// No description provided for @restaurantTransferTitle.
  ///
  /// In ru, this message translates to:
  /// **'Перенос заказа'**
  String get restaurantTransferTitle;

  /// No description provided for @restaurantTransferCurrent.
  ///
  /// In ru, this message translates to:
  /// **'Текущий: {table}'**
  String restaurantTransferCurrent(String table);

  /// No description provided for @restaurantTransferSelectFree.
  ///
  /// In ru, this message translates to:
  /// **'Выберите свободный стол:'**
  String get restaurantTransferSelectFree;

  /// No description provided for @restaurantMergeTitle.
  ///
  /// In ru, this message translates to:
  /// **'Объединить столы'**
  String get restaurantMergeTitle;

  /// No description provided for @restaurantMergeTarget.
  ///
  /// In ru, this message translates to:
  /// **'В стол: {table}'**
  String restaurantMergeTarget(String table);

  /// No description provided for @restaurantMergeSelectSources.
  ///
  /// In ru, this message translates to:
  /// **'Выберите столы для присоединения:'**
  String get restaurantMergeSelectSources;

  /// No description provided for @restaurantMergeNoOpenTables.
  ///
  /// In ru, this message translates to:
  /// **'Нет других занятых столов'**
  String get restaurantMergeNoOpenTables;

  /// No description provided for @restaurantMergeConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Объединить ({count})'**
  String restaurantMergeConfirm(int count);

  /// No description provided for @restaurantMergeDone.
  ///
  /// In ru, this message translates to:
  /// **'Столы объединены'**
  String get restaurantMergeDone;

  /// No description provided for @restaurantMergeNeedTarget.
  ///
  /// In ru, this message translates to:
  /// **'На текущем столе нет открытого заказа'**
  String get restaurantMergeNeedTarget;

  /// No description provided for @restaurantSplitTitle.
  ///
  /// In ru, this message translates to:
  /// **'Разделение счёта'**
  String get restaurantSplitTitle;

  /// No description provided for @restaurantSplitEvenly.
  ///
  /// In ru, this message translates to:
  /// **'Поровну'**
  String get restaurantSplitEvenly;

  /// No description provided for @restaurantSplitByItems.
  ///
  /// In ru, this message translates to:
  /// **'По позициям'**
  String get restaurantSplitByItems;

  /// No description provided for @restaurantSplitGuestCount.
  ///
  /// In ru, this message translates to:
  /// **'Количество гостей'**
  String get restaurantSplitGuestCount;

  /// No description provided for @restaurantSplitPerGuest.
  ///
  /// In ru, this message translates to:
  /// **'На каждого: {amount}'**
  String restaurantSplitPerGuest(String amount);

  /// No description provided for @restaurantSplitGuest.
  ///
  /// In ru, this message translates to:
  /// **'Гость {number}'**
  String restaurantSplitGuest(int number);

  /// No description provided for @restaurantSplitApply.
  ///
  /// In ru, this message translates to:
  /// **'Применить'**
  String get restaurantSplitApply;

  /// No description provided for @restaurantSplitPaymentTitle.
  ///
  /// In ru, this message translates to:
  /// **'Оплата по гостям'**
  String get restaurantSplitPaymentTitle;

  /// No description provided for @restaurantSplitPaymentProceed.
  ///
  /// In ru, this message translates to:
  /// **'К оплате'**
  String get restaurantSplitPaymentProceed;

  /// No description provided for @restaurantPreCheckPrinted.
  ///
  /// In ru, this message translates to:
  /// **'Пре-чек отправлен на печать'**
  String get restaurantPreCheckPrinted;

  /// No description provided for @restaurantPreCheckFailed.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка печати пре-чека'**
  String get restaurantPreCheckFailed;

  /// No description provided for @restaurantSubtotal.
  ///
  /// In ru, this message translates to:
  /// **'Подитог'**
  String get restaurantSubtotal;

  /// No description provided for @restaurantServiceChargeLine.
  ///
  /// In ru, this message translates to:
  /// **'Сервисный сбор ({percent}%)'**
  String restaurantServiceChargeLine(String percent);

  /// No description provided for @restaurantOrderNumber.
  ///
  /// In ru, this message translates to:
  /// **'Заказ #{number}'**
  String restaurantOrderNumber(int number);

  /// No description provided for @restaurantTakeoutNumber.
  ///
  /// In ru, this message translates to:
  /// **'Навынос #{number}'**
  String restaurantTakeoutNumber(int number);

  /// No description provided for @restaurantDeliveryNumber.
  ///
  /// In ru, this message translates to:
  /// **'Доставка #{number}'**
  String restaurantDeliveryNumber(int number);

  /// No description provided for @restaurantSaved.
  ///
  /// In ru, this message translates to:
  /// **'Настройки ресторана сохранены'**
  String get restaurantSaved;

  /// No description provided for @restaurantQuickActions.
  ///
  /// In ru, this message translates to:
  /// **'Быстрые действия'**
  String get restaurantQuickActions;

  /// No description provided for @restaurantNoItems.
  ///
  /// In ru, this message translates to:
  /// **'Нет позиций'**
  String get restaurantNoItems;

  /// No description provided for @restaurantTableSeats.
  ///
  /// In ru, this message translates to:
  /// **'{count} мест'**
  String restaurantTableSeats(int count);

  /// No description provided for @restaurantOrderTab.
  ///
  /// In ru, this message translates to:
  /// **'Заказ'**
  String get restaurantOrderTab;

  /// No description provided for @restaurantMenuTab.
  ///
  /// In ru, this message translates to:
  /// **'Меню'**
  String get restaurantMenuTab;

  /// No description provided for @restaurantGuestLabel.
  ///
  /// In ru, this message translates to:
  /// **'Гость {number}'**
  String restaurantGuestLabel(int number);

  /// No description provided for @restaurantRemoveItem.
  ///
  /// In ru, this message translates to:
  /// **'Удалить позицию'**
  String get restaurantRemoveItem;

  /// No description provided for @restaurantPrintPrecheck.
  ///
  /// In ru, this message translates to:
  /// **'Пречек'**
  String get restaurantPrintPrecheck;

  /// No description provided for @restaurantNewTakeout.
  ///
  /// In ru, this message translates to:
  /// **'Навынос'**
  String get restaurantNewTakeout;

  /// No description provided for @restaurantNewDelivery.
  ///
  /// In ru, this message translates to:
  /// **'Доставка'**
  String get restaurantNewDelivery;

  /// No description provided for @setupSectionOrganization.
  ///
  /// In ru, this message translates to:
  /// **'Организация'**
  String get setupSectionOrganization;

  /// No description provided for @setupSectionContact.
  ///
  /// In ru, this message translates to:
  /// **'Контактное лицо'**
  String get setupSectionContact;

  /// No description provided for @setupSectionAddress.
  ///
  /// In ru, this message translates to:
  /// **'Адреса'**
  String get setupSectionAddress;

  /// No description provided for @setupSectionCashBox.
  ///
  /// In ru, this message translates to:
  /// **'Касса'**
  String get setupSectionCashBox;

  /// No description provided for @setupSectionUsers.
  ///
  /// In ru, this message translates to:
  /// **'Кто будет работать'**
  String get setupSectionUsers;

  /// No description provided for @setupSectionSecurity.
  ///
  /// In ru, this message translates to:
  /// **'Вход по коду'**
  String get setupSectionSecurity;

  /// No description provided for @setupSectionScanner.
  ///
  /// In ru, this message translates to:
  /// **'Сканер'**
  String get setupSectionScanner;

  /// No description provided for @setupSectionScale.
  ///
  /// In ru, this message translates to:
  /// **'Весы'**
  String get setupSectionScale;

  /// No description provided for @setupSectionDisplay.
  ///
  /// In ru, this message translates to:
  /// **'Дисплей покупателя'**
  String get setupSectionDisplay;

  /// No description provided for @setupSectionTerminal.
  ///
  /// In ru, this message translates to:
  /// **'Платёжный терминал'**
  String get setupSectionTerminal;

  /// No description provided for @setupSectionCashback.
  ///
  /// In ru, this message translates to:
  /// **'Возврат наличных'**
  String get setupSectionCashback;

  /// No description provided for @setupTaxIdExplanation.
  ///
  /// In ru, this message translates to:
  /// **'Налоговый номер печатается в каждом чеке и уходит в фискальный сервис. Ошибка здесь обнаружится только при первой сверке с налоговой — когда чеки уже выданы покупателям.'**
  String get setupTaxIdExplanation;

  /// No description provided for @setupFiscalCredentialsExplanation.
  ///
  /// In ru, this message translates to:
  /// **'Реквизиты выдаёт фискальный оператор. Пока они неверны, чеки печатаются как обычно, но в фискальный сервис не уходят — расхождение обнаружится при сверке, а не в момент продажи.'**
  String get setupFiscalCredentialsExplanation;

  /// No description provided for @setupKktNumberExplanation.
  ///
  /// In ru, this message translates to:
  /// **'Номер ККМ связывает кассу с её регистрацией у оператора. Ошибка в нём отправляет чеки под чужой кассой, и заметить это по самой кассе невозможно.'**
  String get setupKktNumberExplanation;

  /// No description provided for @setupStepProgress.
  ///
  /// In ru, this message translates to:
  /// **'Шаг {current} из {total}'**
  String setupStepProgress(int current, int total);

  /// No description provided for @setupStepChecking.
  ///
  /// In ru, this message translates to:
  /// **'Проверка'**
  String get setupStepChecking;

  /// No description provided for @setupStepTelegram.
  ///
  /// In ru, this message translates to:
  /// **'Telegram'**
  String get setupStepTelegram;

  /// No description provided for @setupStepCountry.
  ///
  /// In ru, this message translates to:
  /// **'Страна'**
  String get setupStepCountry;

  /// No description provided for @setupStepOrganization.
  ///
  /// In ru, this message translates to:
  /// **'Организация'**
  String get setupStepOrganization;

  /// No description provided for @setupStepVat.
  ///
  /// In ru, this message translates to:
  /// **'НДС'**
  String get setupStepVat;

  /// No description provided for @setupStepUsers.
  ///
  /// In ru, this message translates to:
  /// **'Пользователи'**
  String get setupStepUsers;

  /// No description provided for @setupStepWorkMode.
  ///
  /// In ru, this message translates to:
  /// **'Режим работы'**
  String get setupStepWorkMode;

  /// No description provided for @setupStepPos.
  ///
  /// In ru, this message translates to:
  /// **'Касса'**
  String get setupStepPos;

  /// No description provided for @setupStepFiscal.
  ///
  /// In ru, this message translates to:
  /// **'Фискализация'**
  String get setupStepFiscal;

  /// No description provided for @setupStepEquipment.
  ///
  /// In ru, this message translates to:
  /// **'Оборудование'**
  String get setupStepEquipment;

  /// No description provided for @setupStepTerminals.
  ///
  /// In ru, this message translates to:
  /// **'Терминалы'**
  String get setupStepTerminals;

  /// No description provided for @setupStepOperatingMode.
  ///
  /// In ru, this message translates to:
  /// **'Тип бизнеса'**
  String get setupStepOperatingMode;

  /// No description provided for @setupStepBusinessRules.
  ///
  /// In ru, this message translates to:
  /// **'Правила'**
  String get setupStepBusinessRules;

  /// No description provided for @setupStepSummary.
  ///
  /// In ru, this message translates to:
  /// **'Проверка'**
  String get setupStepSummary;

  /// No description provided for @setupStepComplete.
  ///
  /// In ru, this message translates to:
  /// **'Готово'**
  String get setupStepComplete;

  /// No description provided for @setupCheckingSettings.
  ///
  /// In ru, this message translates to:
  /// **'Проверка настроек...'**
  String get setupCheckingSettings;

  /// No description provided for @setupStateUnreadableTitle.
  ///
  /// In ru, this message translates to:
  /// **'Касса не ответила'**
  String get setupStateUnreadableTitle;

  /// No description provided for @setupStateUnreadableBody.
  ///
  /// In ru, this message translates to:
  /// **'Мастер не начнёт настройку, пока не прочитает состояние кассы: иначе он может затереть уже работающий магазин. Проверьте, что касса запущена и доступна по сети.'**
  String get setupStateUnreadableBody;

  /// No description provided for @wtUnavailableTitle.
  ///
  /// In ru, this message translates to:
  /// **'Нет связи с кассой'**
  String get wtUnavailableTitle;

  /// No description provided for @wtUnavailableBody.
  ///
  /// In ru, this message translates to:
  /// **'Терминал берёт данные только по WebTransport. Запасного пути нет: если соединения нет, показывать нечего, а показать устаревшее как свежее хуже, чем не показать ничего. Проверьте, что касса запущена, и повторите.'**
  String get wtUnavailableBody;

  /// No description provided for @wtUnavailableReason.
  ///
  /// In ru, this message translates to:
  /// **'Причина: {reason}'**
  String wtUnavailableReason(String reason);

  /// No description provided for @terminalHomeWhoHeader.
  ///
  /// In ru, this message translates to:
  /// **'Кто вошёл'**
  String get terminalHomeWhoHeader;

  /// No description provided for @terminalHomeUserLabel.
  ///
  /// In ru, this message translates to:
  /// **'Кассир'**
  String get terminalHomeUserLabel;

  /// No description provided for @terminalHomeSaleNote.
  ///
  /// In ru, this message translates to:
  /// **'Корзиной, номером чека и сменой владеет касса — терминал показывает чек и командует по проводу. Печать чека, фискализация и денежный ящик остаются на кассе.'**
  String get terminalHomeSaleNote;

  /// No description provided for @wtNotPortedTitle.
  ///
  /// In ru, this message translates to:
  /// **'Этот экран пока только на кассе'**
  String get wtNotPortedTitle;

  /// No description provided for @wtNotPortedBody.
  ///
  /// In ru, this message translates to:
  /// **'Браузерный терминал берёт данные по проводу, и экран появляется здесь тогда, когда все его договоры научились работать поверх провода. Этот ещё не научился. Показать его пустым было бы хуже, чем сказать прямо.'**
  String get wtNotPortedBody;

  /// No description provided for @wtNotPortedLocation.
  ///
  /// In ru, this message translates to:
  /// **'Маршрут: {location}'**
  String wtNotPortedLocation(String location);

  /// No description provided for @setupWelcomeTitle.
  ///
  /// In ru, this message translates to:
  /// **'Добро пожаловать в TelePOS!'**
  String get setupWelcomeTitle;

  /// No description provided for @setupCountryDescription.
  ///
  /// In ru, this message translates to:
  /// **'Выберите вашу страну для настройки валюты и налогов'**
  String get setupCountryDescription;

  /// No description provided for @setupPriceExample.
  ///
  /// In ru, this message translates to:
  /// **'Пример: {amount}'**
  String setupPriceExample(String amount);

  /// No description provided for @setupVatRateLabel.
  ///
  /// In ru, this message translates to:
  /// **'НДС: {rate}%'**
  String setupVatRateLabel(int rate);

  /// No description provided for @setupOrganizationTitle.
  ///
  /// In ru, this message translates to:
  /// **'Данные организации'**
  String get setupOrganizationTitle;

  /// No description provided for @setupOrganizationDescription.
  ///
  /// In ru, this message translates to:
  /// **'Введите информацию о вашей компании'**
  String get setupOrganizationDescription;

  /// No description provided for @setupCompanyNameLabel.
  ///
  /// In ru, this message translates to:
  /// **'Название организации'**
  String get setupCompanyNameLabel;

  /// No description provided for @setupCompanyNameHint.
  ///
  /// In ru, this message translates to:
  /// **'ТОО \"Моя компания\"'**
  String get setupCompanyNameHint;

  /// No description provided for @setupTaxIdDigits.
  ///
  /// In ru, this message translates to:
  /// **'{length} цифр'**
  String setupTaxIdDigits(int length);

  /// No description provided for @setupLegalAddressLabel.
  ///
  /// In ru, this message translates to:
  /// **'Юридический адрес'**
  String get setupLegalAddressLabel;

  /// No description provided for @setupActualAddressLabel.
  ///
  /// In ru, this message translates to:
  /// **'Фактический адрес магазина'**
  String get setupActualAddressLabel;

  /// No description provided for @setupOwnerNameLabel.
  ///
  /// In ru, this message translates to:
  /// **'ФИО руководителя'**
  String get setupOwnerNameLabel;

  /// No description provided for @setupPhoneLabel.
  ///
  /// In ru, this message translates to:
  /// **'Телефон'**
  String get setupPhoneLabel;

  /// No description provided for @setupVatTitle.
  ///
  /// In ru, this message translates to:
  /// **'Налог на добавленную стоимость'**
  String get setupVatTitle;

  /// No description provided for @setupVatDescription.
  ///
  /// In ru, this message translates to:
  /// **'Выберите режим налогообложения вашей организации'**
  String get setupVatDescription;

  /// No description provided for @setupVatPayerTitle.
  ///
  /// In ru, this message translates to:
  /// **'Плательщик НДС'**
  String get setupVatPayerTitle;

  /// No description provided for @setupVatPayerRate.
  ///
  /// In ru, this message translates to:
  /// **'Ставка НДС: {rate}%'**
  String setupVatPayerRate(String rate);

  /// No description provided for @setupVatPayerRateUnknown.
  ///
  /// In ru, this message translates to:
  /// **'Ставка НДС зависит от страны'**
  String get setupVatPayerRateUnknown;

  /// No description provided for @setupVatPayerDescription.
  ///
  /// In ru, this message translates to:
  /// **'В чеках будет выделяться НДС.\nОбязательно для компаний на общей системе налогообложения.'**
  String get setupVatPayerDescription;

  /// No description provided for @setupVatNonPayerTitle.
  ///
  /// In ru, this message translates to:
  /// **'Без НДС'**
  String get setupVatNonPayerTitle;

  /// No description provided for @setupVatNonPayerSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'НДС не применяется'**
  String get setupVatNonPayerSubtitle;

  /// No description provided for @setupVatNonPayerDescription.
  ///
  /// In ru, this message translates to:
  /// **'В чеках НДС выделяться не будет.\nДля ИП на упрощённой системе или патенте.'**
  String get setupVatNonPayerDescription;

  /// No description provided for @setupWorkModeTitle.
  ///
  /// In ru, this message translates to:
  /// **'Режим работы'**
  String get setupWorkModeTitle;

  /// No description provided for @setupWorkModeDescription.
  ///
  /// In ru, this message translates to:
  /// **'Выберите как будет работать ваша касса'**
  String get setupWorkModeDescription;

  /// No description provided for @setupAutonomousTitle.
  ///
  /// In ru, this message translates to:
  /// **'Автономный режим'**
  String get setupAutonomousTitle;

  /// No description provided for @setupAutonomousSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Работа без интернета'**
  String get setupAutonomousSubtitle;

  /// No description provided for @setupAutonomousDescription.
  ///
  /// In ru, this message translates to:
  /// **'Касса работает полностью автономно.\nДанные хранятся только локально.\nНет синхронизации между кассами.'**
  String get setupAutonomousDescription;

  /// No description provided for @setupNetworkTitle.
  ///
  /// In ru, this message translates to:
  /// **'Сетевой режим'**
  String get setupNetworkTitle;

  /// No description provided for @setupNetworkConfigured.
  ///
  /// In ru, this message translates to:
  /// **'Telegram настроен'**
  String get setupNetworkConfigured;

  /// No description provided for @setupNetworkRequired.
  ///
  /// In ru, this message translates to:
  /// **'Требуется Telegram'**
  String get setupNetworkRequired;

  /// No description provided for @setupNetworkDescription.
  ///
  /// In ru, this message translates to:
  /// **'Синхронизация данных между кассами.\nРезервное копирование в облако.\nОтчёты и уведомления в Telegram.'**
  String get setupNetworkDescription;

  /// No description provided for @setupNetworkRequiresTelegram.
  ///
  /// In ru, this message translates to:
  /// **'Для сетевого режима необходимо настроить Telegram'**
  String get setupNetworkRequiresTelegram;

  /// No description provided for @setupOperatingModeTitle.
  ///
  /// In ru, this message translates to:
  /// **'Тип бизнеса'**
  String get setupOperatingModeTitle;

  /// No description provided for @setupOperatingModeDescription.
  ///
  /// In ru, this message translates to:
  /// **'Выберите тип вашего бизнеса'**
  String get setupOperatingModeDescription;

  /// No description provided for @setupRetailTitle.
  ///
  /// In ru, this message translates to:
  /// **'Розничная касса'**
  String get setupRetailTitle;

  /// No description provided for @setupRetailSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Магазин, аптека, супермаркет'**
  String get setupRetailSubtitle;

  /// No description provided for @setupRetailDescription.
  ///
  /// In ru, this message translates to:
  /// **'Стандартный POS для розничной торговли.\nПродажи, возвраты, приёмка товара.\nСмены и отчётность.'**
  String get setupRetailDescription;

  /// No description provided for @setupRestaurantTitle.
  ///
  /// In ru, this message translates to:
  /// **'Ресторан / Кафе'**
  String get setupRestaurantTitle;

  /// No description provided for @setupRestaurantSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Столы, заказы, доставка'**
  String get setupRestaurantSubtitle;

  /// No description provided for @setupRestaurantDescription.
  ///
  /// In ru, this message translates to:
  /// **'Управление столами и залом.\nНавынос и доставка.\nРазделение счёта и сервисный сбор.'**
  String get setupRestaurantDescription;

  /// No description provided for @setupServiceTitle.
  ///
  /// In ru, this message translates to:
  /// **'Сервисный центр'**
  String get setupServiceTitle;

  /// No description provided for @setupServiceSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Ремонт, услуги, процедуры'**
  String get setupServiceSubtitle;

  /// No description provided for @setupServiceDescription.
  ///
  /// In ru, this message translates to:
  /// **'Приём в ремонт/обслуживание.\nЗаказ-наряды и отметки работ.\nОтслеживание статуса и выдача.'**
  String get setupServiceDescription;

  /// No description provided for @setupPosConfigTitle.
  ///
  /// In ru, this message translates to:
  /// **'Настройка кассы'**
  String get setupPosConfigTitle;

  /// No description provided for @setupPosConfigDescription.
  ///
  /// In ru, this message translates to:
  /// **'Укажите параметры кассового аппарата'**
  String get setupPosConfigDescription;

  /// No description provided for @setupCashBoxNameLabel.
  ///
  /// In ru, this message translates to:
  /// **'Название кассы'**
  String get setupCashBoxNameLabel;

  /// No description provided for @setupCashBoxNameHint.
  ///
  /// In ru, this message translates to:
  /// **'Касса 1'**
  String get setupCashBoxNameHint;

  /// No description provided for @setupPosIdLabel.
  ///
  /// In ru, this message translates to:
  /// **'ID кассы'**
  String get setupPosIdLabel;

  /// No description provided for @setupPrinterConfigTitle.
  ///
  /// In ru, this message translates to:
  /// **'Принтер чеков'**
  String get setupPrinterConfigTitle;

  /// No description provided for @setupPaperWidthLabel.
  ///
  /// In ru, this message translates to:
  /// **'Ширина бумаги'**
  String get setupPaperWidthLabel;

  /// No description provided for @setupPaperWidth58.
  ///
  /// In ru, this message translates to:
  /// **'58 мм (32 символа)'**
  String get setupPaperWidth58;

  /// No description provided for @setupPaperWidth80.
  ///
  /// In ru, this message translates to:
  /// **'80 мм (48 символов)'**
  String get setupPaperWidth80;

  /// No description provided for @setupPrinterHeaderLabel.
  ///
  /// In ru, this message translates to:
  /// **'Заголовок чека'**
  String get setupPrinterHeaderLabel;

  /// No description provided for @setupPrinterHeaderHint.
  ///
  /// In ru, this message translates to:
  /// **'Название магазина\nАдрес'**
  String get setupPrinterHeaderHint;

  /// No description provided for @setupPrinterFooterLabel.
  ///
  /// In ru, this message translates to:
  /// **'Подвал чека'**
  String get setupPrinterFooterLabel;

  /// No description provided for @setupPrinterFooterHint.
  ///
  /// In ru, this message translates to:
  /// **'Спасибо за покупку!'**
  String get setupPrinterFooterHint;

  /// No description provided for @setupFiscalNotRequired.
  ///
  /// In ru, this message translates to:
  /// **'Для вашей страны фискализация не требуется'**
  String get setupFiscalNotRequired;

  /// No description provided for @setupFiscalDescription.
  ///
  /// In ru, this message translates to:
  /// **'Настройте подключение к фискальному оператору'**
  String get setupFiscalDescription;

  /// No description provided for @setupEnableWebkassa.
  ///
  /// In ru, this message translates to:
  /// **'Включить WebKassa'**
  String get setupEnableWebkassa;

  /// No description provided for @setupEnableOfd.
  ///
  /// In ru, this message translates to:
  /// **'Включить ОФД'**
  String get setupEnableOfd;

  /// No description provided for @setupWebkassaDescription.
  ///
  /// In ru, this message translates to:
  /// **'Фискализация чеков через WebKassa (Казахстан)'**
  String get setupWebkassaDescription;

  /// No description provided for @setupOfdDescription.
  ///
  /// In ru, this message translates to:
  /// **'Фискализация чеков через ОФД (Россия)'**
  String get setupOfdDescription;

  /// No description provided for @setupSkipLater.
  ///
  /// In ru, this message translates to:
  /// **'Пропустить (настроить позже)'**
  String get setupSkipLater;

  /// No description provided for @setupWebkassaAccountTitle.
  ///
  /// In ru, this message translates to:
  /// **'Аккаунт WebKassa'**
  String get setupWebkassaAccountTitle;

  /// No description provided for @setupWebkassaAccountIdLabel.
  ///
  /// In ru, this message translates to:
  /// **'ID аккаунта'**
  String get setupWebkassaAccountIdLabel;

  /// No description provided for @setupWebkassaAccountIdHint.
  ///
  /// In ru, this message translates to:
  /// **'Ваш ID в WebKassa'**
  String get setupWebkassaAccountIdHint;

  /// No description provided for @setupWebkassaTokenLabel.
  ///
  /// In ru, this message translates to:
  /// **'Токен аккаунта'**
  String get setupWebkassaTokenLabel;

  /// No description provided for @setupWebkassaTokenHint.
  ///
  /// In ru, this message translates to:
  /// **'API токен'**
  String get setupWebkassaTokenHint;

  /// No description provided for @setupWebkassaPosTitle.
  ///
  /// In ru, this message translates to:
  /// **'Касса WebKassa'**
  String get setupWebkassaPosTitle;

  /// No description provided for @setupWebkassaPosIdLabel.
  ///
  /// In ru, this message translates to:
  /// **'ID кассы'**
  String get setupWebkassaPosIdLabel;

  /// No description provided for @setupWebkassaPosIdHint.
  ///
  /// In ru, this message translates to:
  /// **'ID кассы в WebKassa'**
  String get setupWebkassaPosIdHint;

  /// No description provided for @setupWebkassaPosTokenLabel.
  ///
  /// In ru, this message translates to:
  /// **'Токен кассы'**
  String get setupWebkassaPosTokenLabel;

  /// No description provided for @setupWebkassaPosTokenHint.
  ///
  /// In ru, this message translates to:
  /// **'Токен кассы'**
  String get setupWebkassaPosTokenHint;

  /// No description provided for @setupWebkassaFactoryNoLabel.
  ///
  /// In ru, this message translates to:
  /// **'Заводской номер ККМ'**
  String get setupWebkassaFactoryNoLabel;

  /// No description provided for @setupOfdParamsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Параметры ОФД'**
  String get setupOfdParamsTitle;

  /// No description provided for @setupOfdInnLabel.
  ///
  /// In ru, this message translates to:
  /// **'ИНН организации'**
  String get setupOfdInnLabel;

  /// No description provided for @setupOfdKktRegNoLabel.
  ///
  /// In ru, this message translates to:
  /// **'Рег. номер ККТ'**
  String get setupOfdKktRegNoLabel;

  /// No description provided for @setupOfdFnNoLabel.
  ///
  /// In ru, this message translates to:
  /// **'Номер ФН'**
  String get setupOfdFnNoLabel;

  /// No description provided for @setupOfdUrlLabel.
  ///
  /// In ru, this message translates to:
  /// **'URL ОФД'**
  String get setupOfdUrlLabel;

  /// No description provided for @setupEquipmentTitle.
  ///
  /// In ru, this message translates to:
  /// **'Оборудование'**
  String get setupEquipmentTitle;

  /// No description provided for @setupEquipmentDescription.
  ///
  /// In ru, this message translates to:
  /// **'Настройте подключённое оборудование'**
  String get setupEquipmentDescription;

  /// No description provided for @setupEquipmentPrinter.
  ///
  /// In ru, this message translates to:
  /// **'Принтер чеков'**
  String get setupEquipmentPrinter;

  /// No description provided for @setupEquipmentScanner.
  ///
  /// In ru, this message translates to:
  /// **'Сканер штрихкодов'**
  String get setupEquipmentScanner;

  /// No description provided for @setupEquipmentScales.
  ///
  /// In ru, this message translates to:
  /// **'Весы'**
  String get setupEquipmentScales;

  /// No description provided for @setupEquipmentCashDrawer.
  ///
  /// In ru, this message translates to:
  /// **'Денежный ящик'**
  String get setupEquipmentCashDrawer;

  /// No description provided for @setupEquipmentDisplay.
  ///
  /// In ru, this message translates to:
  /// **'Дисплей покупателя'**
  String get setupEquipmentDisplay;

  /// No description provided for @setupConnectionTypeLabel.
  ///
  /// In ru, this message translates to:
  /// **'Тип подключения'**
  String get setupConnectionTypeLabel;

  /// No description provided for @setupConnectionUsb.
  ///
  /// In ru, this message translates to:
  /// **'USB'**
  String get setupConnectionUsb;

  /// No description provided for @setupConnectionBluetooth.
  ///
  /// In ru, this message translates to:
  /// **'Bluetooth'**
  String get setupConnectionBluetooth;

  /// No description provided for @setupConnectionWifi.
  ///
  /// In ru, this message translates to:
  /// **'Wi-Fi / Ethernet'**
  String get setupConnectionWifi;

  /// No description provided for @setupConnectionSerial.
  ///
  /// In ru, this message translates to:
  /// **'COM-порт'**
  String get setupConnectionSerial;

  /// No description provided for @setupConnectionNone.
  ///
  /// In ru, this message translates to:
  /// **'Не выбран'**
  String get setupConnectionNone;

  /// No description provided for @setupPrinterIpLabel.
  ///
  /// In ru, this message translates to:
  /// **'IP-адрес принтера'**
  String get setupPrinterIpLabel;

  /// No description provided for @setupPrinterMacLabel.
  ///
  /// In ru, this message translates to:
  /// **'MAC-адрес принтера'**
  String get setupPrinterMacLabel;

  /// No description provided for @setupPrinterNameLabel.
  ///
  /// In ru, this message translates to:
  /// **'Название принтера'**
  String get setupPrinterNameLabel;

  /// No description provided for @setupPrinterNameHint.
  ///
  /// In ru, this message translates to:
  /// **'Кухонный принтер'**
  String get setupPrinterNameHint;

  /// No description provided for @setupScannerTypeLabel.
  ///
  /// In ru, this message translates to:
  /// **'Тип сканера'**
  String get setupScannerTypeLabel;

  /// No description provided for @setupScannerCamera.
  ///
  /// In ru, this message translates to:
  /// **'Камера устройства'**
  String get setupScannerCamera;

  /// No description provided for @setupScannerUsb.
  ///
  /// In ru, this message translates to:
  /// **'USB-сканер'**
  String get setupScannerUsb;

  /// No description provided for @setupScannerBluetooth.
  ///
  /// In ru, this message translates to:
  /// **'Bluetooth-сканер'**
  String get setupScannerBluetooth;

  /// No description provided for @setupScalePortLabel.
  ///
  /// In ru, this message translates to:
  /// **'COM-порт'**
  String get setupScalePortLabel;

  /// No description provided for @setupBaudRateLabel.
  ///
  /// In ru, this message translates to:
  /// **'Скорость (baud rate)'**
  String get setupBaudRateLabel;

  /// No description provided for @setupCashDrawerConnected.
  ///
  /// In ru, this message translates to:
  /// **'Подключён к принтеру'**
  String get setupCashDrawerConnected;

  /// No description provided for @setupCashDrawerConnectedDesc.
  ///
  /// In ru, this message translates to:
  /// **'Открывается командой принтера'**
  String get setupCashDrawerConnectedDesc;

  /// No description provided for @setupSkip.
  ///
  /// In ru, this message translates to:
  /// **'Пропустить'**
  String get setupSkip;

  /// No description provided for @setupPaymentTerminalsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Платёжные терминалы'**
  String get setupPaymentTerminalsTitle;

  /// No description provided for @setupPaymentTerminalsDescription.
  ///
  /// In ru, this message translates to:
  /// **'Настройте интеграцию с платёжными системами'**
  String get setupPaymentTerminalsDescription;

  /// No description provided for @setupKaspiIpLabel.
  ///
  /// In ru, this message translates to:
  /// **'IP-адрес терминала'**
  String get setupKaspiIpLabel;

  /// No description provided for @setupPortLabel.
  ///
  /// In ru, this message translates to:
  /// **'Порт'**
  String get setupPortLabel;

  /// No description provided for @setupApiUrlLabel.
  ///
  /// In ru, this message translates to:
  /// **'API URL'**
  String get setupApiUrlLabel;

  /// No description provided for @setupApiKeyLabel.
  ///
  /// In ru, this message translates to:
  /// **'API ключ'**
  String get setupApiKeyLabel;

  /// No description provided for @setupNoTerminalsAvailable.
  ///
  /// In ru, this message translates to:
  /// **'Для вашего региона нет доступных платёжных терминалов'**
  String get setupNoTerminalsAvailable;

  /// No description provided for @setupBusinessRulesTitle.
  ///
  /// In ru, this message translates to:
  /// **'Бизнес-правила'**
  String get setupBusinessRulesTitle;

  /// No description provided for @setupBusinessRulesDescription.
  ///
  /// In ru, this message translates to:
  /// **'Настройте правила работы кассы'**
  String get setupBusinessRulesDescription;

  /// No description provided for @setupPermissionsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Разрешения'**
  String get setupPermissionsTitle;

  /// No description provided for @setupAllowDiscounts.
  ///
  /// In ru, this message translates to:
  /// **'Скидки'**
  String get setupAllowDiscounts;

  /// No description provided for @setupAllowDiscountsDesc.
  ///
  /// In ru, this message translates to:
  /// **'Разрешить применение скидок'**
  String get setupAllowDiscountsDesc;

  /// No description provided for @setupAllowDebtSales.
  ///
  /// In ru, this message translates to:
  /// **'Продажа в долг'**
  String get setupAllowDebtSales;

  /// No description provided for @setupAllowDebtSalesDesc.
  ///
  /// In ru, this message translates to:
  /// **'Разрешить продажу в кредит'**
  String get setupAllowDebtSalesDesc;

  /// No description provided for @setupAllowPriceEdit.
  ///
  /// In ru, this message translates to:
  /// **'Редактирование цен'**
  String get setupAllowPriceEdit;

  /// No description provided for @setupAllowPriceEditDesc.
  ///
  /// In ru, this message translates to:
  /// **'Разрешить изменение цен при продаже'**
  String get setupAllowPriceEditDesc;

  /// No description provided for @setupAllowCashInOut.
  ///
  /// In ru, this message translates to:
  /// **'Кассовые операции'**
  String get setupAllowCashInOut;

  /// No description provided for @setupAllowCashInOutDesc.
  ///
  /// In ru, this message translates to:
  /// **'Внесение и выдача наличных'**
  String get setupAllowCashInOutDesc;

  /// No description provided for @setupBlockPriceDecrease.
  ///
  /// In ru, this message translates to:
  /// **'Блокировать снижение цен'**
  String get setupBlockPriceDecrease;

  /// No description provided for @setupBlockPriceDecreaseDesc.
  ///
  /// In ru, this message translates to:
  /// **'Запретить продажу ниже установленной цены'**
  String get setupBlockPriceDecreaseDesc;

  /// No description provided for @setupLimitsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Лимиты'**
  String get setupLimitsTitle;

  /// No description provided for @setupAllowBigAmount.
  ///
  /// In ru, this message translates to:
  /// **'Крупные суммы'**
  String get setupAllowBigAmount;

  /// No description provided for @setupAllowBigAmountDesc.
  ///
  /// In ru, this message translates to:
  /// **'Разрешить операции > 1 000 000'**
  String get setupAllowBigAmountDesc;

  /// No description provided for @setupCashWithdrawalLimitLabel.
  ///
  /// In ru, this message translates to:
  /// **'Лимит выдачи наличных'**
  String get setupCashWithdrawalLimitLabel;

  /// No description provided for @setupCashWithdrawalLimitHelper.
  ///
  /// In ru, this message translates to:
  /// **'Оставьте пустым для без лимита'**
  String get setupCashWithdrawalLimitHelper;

  /// No description provided for @setupLoyaltyTitle.
  ///
  /// In ru, this message translates to:
  /// **'Программа лояльности'**
  String get setupLoyaltyTitle;

  /// No description provided for @setupCashbackLabel.
  ///
  /// In ru, this message translates to:
  /// **'Кешбэк'**
  String get setupCashbackLabel;

  /// No description provided for @setupCashbackDesc.
  ///
  /// In ru, this message translates to:
  /// **'Включить начисление бонусов'**
  String get setupCashbackDesc;

  /// No description provided for @setupCashbackRateLabel.
  ///
  /// In ru, this message translates to:
  /// **'Процент кешбэка'**
  String get setupCashbackRateLabel;

  /// No description provided for @setupRoundingTitle.
  ///
  /// In ru, this message translates to:
  /// **'Округление'**
  String get setupRoundingTitle;

  /// No description provided for @setupDiscountRounding.
  ///
  /// In ru, this message translates to:
  /// **'Округление скидок'**
  String get setupDiscountRounding;

  /// No description provided for @setupWeightRounding.
  ///
  /// In ru, this message translates to:
  /// **'Округление весовых товаров'**
  String get setupWeightRounding;

  /// No description provided for @setupRoundingNone.
  ///
  /// In ru, this message translates to:
  /// **'Без округления'**
  String get setupRoundingNone;

  /// No description provided for @setupRoundingUp1.
  ///
  /// In ru, this message translates to:
  /// **'До 1 (вверх)'**
  String get setupRoundingUp1;

  /// No description provided for @setupRoundingDown1.
  ///
  /// In ru, this message translates to:
  /// **'До 1 (вниз)'**
  String get setupRoundingDown1;

  /// No description provided for @setupRoundingUp5.
  ///
  /// In ru, this message translates to:
  /// **'До 5 (вверх)'**
  String get setupRoundingUp5;

  /// No description provided for @setupRoundingDown5.
  ///
  /// In ru, this message translates to:
  /// **'До 5 (вниз)'**
  String get setupRoundingDown5;

  /// No description provided for @setupRoundingUp10.
  ///
  /// In ru, this message translates to:
  /// **'До 10 (вверх)'**
  String get setupRoundingUp10;

  /// No description provided for @setupRoundingDown10.
  ///
  /// In ru, this message translates to:
  /// **'До 10 (вниз)'**
  String get setupRoundingDown10;

  /// No description provided for @setupFiscalDisablesRounding.
  ///
  /// In ru, this message translates to:
  /// **'При включённой фискализации округление автоматически отключается'**
  String get setupFiscalDisablesRounding;

  /// No description provided for @setupUserCreationTitle.
  ///
  /// In ru, this message translates to:
  /// **'Создание пользователей'**
  String get setupUserCreationTitle;

  /// No description provided for @setupUserCreationDescription.
  ///
  /// In ru, this message translates to:
  /// **'Создайте пользователей для работы с кассой'**
  String get setupUserCreationDescription;

  /// No description provided for @setupAdminLabel.
  ///
  /// In ru, this message translates to:
  /// **'Администратор'**
  String get setupAdminLabel;

  /// No description provided for @setupAdminSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Владелец кассы'**
  String get setupAdminSubtitle;

  /// No description provided for @setupUserNameLabel.
  ///
  /// In ru, this message translates to:
  /// **'Имя'**
  String get setupUserNameLabel;

  /// No description provided for @setupUserPinLabel.
  ///
  /// In ru, this message translates to:
  /// **'PIN'**
  String get setupUserPinLabel;

  /// No description provided for @setupUserPinConfirmLabel.
  ///
  /// In ru, this message translates to:
  /// **'Подтверждение'**
  String get setupUserPinConfirmLabel;

  /// No description provided for @setupAdminPinDefault.
  ///
  /// In ru, this message translates to:
  /// **'По умолчанию: 0000'**
  String get setupAdminPinDefault;

  /// No description provided for @setupSellerLabel.
  ///
  /// In ru, this message translates to:
  /// **'Продавец'**
  String get setupSellerLabel;

  /// No description provided for @setupSellerOptional.
  ///
  /// In ru, this message translates to:
  /// **'Опционально'**
  String get setupSellerOptional;

  /// No description provided for @setupSellerPinDefault.
  ///
  /// In ru, this message translates to:
  /// **'По умолчанию: 1111'**
  String get setupSellerPinDefault;

  /// No description provided for @setupAdminPinMismatch.
  ///
  /// In ru, this message translates to:
  /// **'PIN-коды администратора не совпадают'**
  String get setupAdminPinMismatch;

  /// No description provided for @setupSummaryTitle.
  ///
  /// In ru, this message translates to:
  /// **'Проверьте данные'**
  String get setupSummaryTitle;

  /// No description provided for @setupSummaryDescription.
  ///
  /// In ru, this message translates to:
  /// **'Убедитесь, что всё указано верно'**
  String get setupSummaryDescription;

  /// No description provided for @setupSummaryCountry.
  ///
  /// In ru, this message translates to:
  /// **'Страна'**
  String get setupSummaryCountry;

  /// No description provided for @setupSummaryCurrency.
  ///
  /// In ru, this message translates to:
  /// **'Валюта'**
  String get setupSummaryCurrency;

  /// No description provided for @setupSummaryFormat.
  ///
  /// In ru, this message translates to:
  /// **'Формат'**
  String get setupSummaryFormat;

  /// No description provided for @setupSummaryVat.
  ///
  /// In ru, this message translates to:
  /// **'НДС'**
  String get setupSummaryVat;

  /// No description provided for @setupSummaryTelegram.
  ///
  /// In ru, this message translates to:
  /// **'Telegram'**
  String get setupSummaryTelegram;

  /// No description provided for @setupSummaryStatus.
  ///
  /// In ru, this message translates to:
  /// **'Статус'**
  String get setupSummaryStatus;

  /// No description provided for @setupConfigured.
  ///
  /// In ru, this message translates to:
  /// **'Настроен'**
  String get setupConfigured;

  /// No description provided for @setupNotConfigured.
  ///
  /// In ru, this message translates to:
  /// **'Не настроен'**
  String get setupNotConfigured;

  /// No description provided for @setupSummaryOrganization.
  ///
  /// In ru, this message translates to:
  /// **'Организация'**
  String get setupSummaryOrganization;

  /// No description provided for @setupSummaryName.
  ///
  /// In ru, this message translates to:
  /// **'Название'**
  String get setupSummaryName;

  /// No description provided for @setupSummaryAddress.
  ///
  /// In ru, this message translates to:
  /// **'Адрес'**
  String get setupSummaryAddress;

  /// No description provided for @setupSummaryWorkMode.
  ///
  /// In ru, this message translates to:
  /// **'Режим работы'**
  String get setupSummaryWorkMode;

  /// No description provided for @setupSummaryMode.
  ///
  /// In ru, this message translates to:
  /// **'Режим'**
  String get setupSummaryMode;

  /// No description provided for @setupSummaryAutonomous.
  ///
  /// In ru, this message translates to:
  /// **'Автономный (без сети)'**
  String get setupSummaryAutonomous;

  /// No description provided for @setupSummaryNetwork.
  ///
  /// In ru, this message translates to:
  /// **'Сетевой (синхронизация)'**
  String get setupSummaryNetwork;

  /// No description provided for @setupSummaryPos.
  ///
  /// In ru, this message translates to:
  /// **'Касса'**
  String get setupSummaryPos;

  /// No description provided for @setupSummaryId.
  ///
  /// In ru, this message translates to:
  /// **'ID'**
  String get setupSummaryId;

  /// No description provided for @setupEnabled.
  ///
  /// In ru, this message translates to:
  /// **'Включена'**
  String get setupEnabled;

  /// No description provided for @setupDisabled.
  ///
  /// In ru, this message translates to:
  /// **'Отключена'**
  String get setupDisabled;

  /// No description provided for @setupSummaryFiscalType.
  ///
  /// In ru, this message translates to:
  /// **'Тип'**
  String get setupSummaryFiscalType;

  /// No description provided for @setupSummaryEquipment.
  ///
  /// In ru, this message translates to:
  /// **'Оборудование'**
  String get setupSummaryEquipment;

  /// No description provided for @setupSummaryPrinter.
  ///
  /// In ru, this message translates to:
  /// **'Принтер'**
  String get setupSummaryPrinter;

  /// No description provided for @setupSummaryScanner.
  ///
  /// In ru, this message translates to:
  /// **'Сканер'**
  String get setupSummaryScanner;

  /// No description provided for @setupSummaryScales.
  ///
  /// In ru, this message translates to:
  /// **'Весы'**
  String get setupSummaryScales;

  /// No description provided for @setupSummaryCashDrawer.
  ///
  /// In ru, this message translates to:
  /// **'Ден. ящик'**
  String get setupSummaryCashDrawer;

  /// No description provided for @setupSummaryTerminals.
  ///
  /// In ru, this message translates to:
  /// **'Платёжные терминалы'**
  String get setupSummaryTerminals;

  /// No description provided for @setupSummaryRules.
  ///
  /// In ru, this message translates to:
  /// **'Бизнес-правила'**
  String get setupSummaryRules;

  /// No description provided for @setupSummaryDiscounts.
  ///
  /// In ru, this message translates to:
  /// **'Скидки'**
  String get setupSummaryDiscounts;

  /// No description provided for @setupSummaryDebtSales.
  ///
  /// In ru, this message translates to:
  /// **'В долг'**
  String get setupSummaryDebtSales;

  /// No description provided for @setupSummaryCashback.
  ///
  /// In ru, this message translates to:
  /// **'Кешбэк'**
  String get setupSummaryCashback;

  /// No description provided for @setupSummaryBigAmount.
  ///
  /// In ru, this message translates to:
  /// **'Крупные суммы'**
  String get setupSummaryBigAmount;

  /// No description provided for @setupSummaryUsers.
  ///
  /// In ru, this message translates to:
  /// **'Пользователи'**
  String get setupSummaryUsers;

  /// No description provided for @setupSummaryAdmin.
  ///
  /// In ru, this message translates to:
  /// **'Администратор'**
  String get setupSummaryAdmin;

  /// No description provided for @setupSummarySeller.
  ///
  /// In ru, this message translates to:
  /// **'Продавец'**
  String get setupSummarySeller;

  /// No description provided for @setupCompleteTitle.
  ///
  /// In ru, this message translates to:
  /// **'Настройка завершена!'**
  String get setupCompleteTitle;

  /// No description provided for @setupCompleteSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Касса готова к работе'**
  String get setupCompleteSubtitle;

  /// No description provided for @setupStartWork.
  ///
  /// In ru, this message translates to:
  /// **'Начать работу'**
  String get setupStartWork;

  /// No description provided for @setupVatPayerSummary.
  ///
  /// In ru, this message translates to:
  /// **'Плательщик НДС ({rate}%)'**
  String setupVatPayerSummary(String rate);

  /// No description provided for @setupSummaryWkPosId.
  ///
  /// In ru, this message translates to:
  /// **'ID кассы WK'**
  String get setupSummaryWkPosId;

  /// No description provided for @setupSummaryOfdInn.
  ///
  /// In ru, this message translates to:
  /// **'ИНН'**
  String get setupSummaryOfdInn;

  /// No description provided for @setupScalesConfigured.
  ///
  /// In ru, this message translates to:
  /// **'Настроены'**
  String get setupScalesConfigured;

  /// No description provided for @setupScalesNotConfigured.
  ///
  /// In ru, this message translates to:
  /// **'Не настроены'**
  String get setupScalesNotConfigured;

  /// No description provided for @setupCashDrawerOn.
  ///
  /// In ru, this message translates to:
  /// **'Включён'**
  String get setupCashDrawerOn;

  /// No description provided for @setupAllowed.
  ///
  /// In ru, this message translates to:
  /// **'Разрешены'**
  String get setupAllowed;

  /// No description provided for @setupDenied.
  ///
  /// In ru, this message translates to:
  /// **'Запрещены'**
  String get setupDenied;

  /// No description provided for @setupAllowedFem.
  ///
  /// In ru, this message translates to:
  /// **'Разрешена'**
  String get setupAllowedFem;

  /// No description provided for @setupDeniedFem.
  ///
  /// In ru, this message translates to:
  /// **'Запрещена'**
  String get setupDeniedFem;

  /// No description provided for @setupCashbackOff.
  ///
  /// In ru, this message translates to:
  /// **'Отключён'**
  String get setupCashbackOff;

  /// No description provided for @setupBigAmountLimit.
  ///
  /// In ru, this message translates to:
  /// **'Лимит 100 000'**
  String get setupBigAmountLimit;

  /// No description provided for @setupDisplayPortLabel.
  ///
  /// In ru, this message translates to:
  /// **'COM-порт'**
  String get setupDisplayPortLabel;

  /// No description provided for @telegramAuthSkip.
  ///
  /// In ru, this message translates to:
  /// **'Пропустить (настроить позже)'**
  String get telegramAuthSkip;

  /// No description provided for @telegramInitializing.
  ///
  /// In ru, this message translates to:
  /// **'Инициализация'**
  String get telegramInitializing;

  /// No description provided for @telegramErrorTdlib.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка TDLib'**
  String get telegramErrorTdlib;

  /// No description provided for @telegramAuthLogin.
  ///
  /// In ru, this message translates to:
  /// **'Вход в Telegram'**
  String get telegramAuthLogin;

  /// No description provided for @telegramAuthCodeStep.
  ///
  /// In ru, this message translates to:
  /// **'Код подтверждения'**
  String get telegramAuthCodeStep;

  /// No description provided for @telegramAuth2fa.
  ///
  /// In ru, this message translates to:
  /// **'Двухфакторная аутентификация'**
  String get telegramAuth2fa;

  /// No description provided for @telegramRegister.
  ///
  /// In ru, this message translates to:
  /// **'Регистрация'**
  String get telegramRegister;

  /// No description provided for @telegramSearchingChannels.
  ///
  /// In ru, this message translates to:
  /// **'Поиск каналов'**
  String get telegramSearchingChannels;

  /// No description provided for @telegramLoadingData.
  ///
  /// In ru, this message translates to:
  /// **'Загрузка данных'**
  String get telegramLoadingData;

  /// No description provided for @telegramOrgData.
  ///
  /// In ru, this message translates to:
  /// **'Данные организации'**
  String get telegramOrgData;

  /// No description provided for @telegramSetupChannels.
  ///
  /// In ru, this message translates to:
  /// **'Настройка каналов'**
  String get telegramSetupChannels;

  /// No description provided for @telegramSetupEncryption.
  ///
  /// In ru, this message translates to:
  /// **'Настройка шифрования'**
  String get telegramSetupEncryption;

  /// No description provided for @telegramSetupComplete.
  ///
  /// In ru, this message translates to:
  /// **'Готово'**
  String get telegramSetupComplete;

  /// No description provided for @telegramInitializingLong.
  ///
  /// In ru, this message translates to:
  /// **'Инициализация Telegram...'**
  String get telegramInitializingLong;

  /// No description provided for @telegramConnecting.
  ///
  /// In ru, this message translates to:
  /// **'Подключение к серверам Telegram'**
  String get telegramConnecting;

  /// No description provided for @telegramTdlibNotFound.
  ///
  /// In ru, this message translates to:
  /// **'TDLib не найден'**
  String get telegramTdlibNotFound;

  /// No description provided for @telegramTdlibErrorMessage.
  ///
  /// In ru, this message translates to:
  /// **'Нативная библиотека TDLib не найдена.\nДля работы с Telegram необходимо установить tdjson.'**
  String get telegramTdlibErrorMessage;

  /// No description provided for @telegramForWindows.
  ///
  /// In ru, this message translates to:
  /// **'Для Windows:'**
  String get telegramForWindows;

  /// No description provided for @telegramWindowsInstructions.
  ///
  /// In ru, this message translates to:
  /// **'1. Скачайте TDLib: github.com/tdlib/td/releases\n2. Скопируйте tdjson.dll в корень проекта\n3. Или установите в C:\\TDLib\\bin\\'**
  String get telegramWindowsInstructions;

  /// No description provided for @telegramPhoneAuthTitle.
  ///
  /// In ru, this message translates to:
  /// **'Вход по номеру телефона'**
  String get telegramPhoneAuthTitle;

  /// No description provided for @telegramPhoneAuthDescription.
  ///
  /// In ru, this message translates to:
  /// **'Введите номер телефона, привязанный к вашему аккаунту Telegram'**
  String get telegramPhoneAuthDescription;

  /// No description provided for @telegramCountryCodeLabel.
  ///
  /// In ru, this message translates to:
  /// **'Код страны'**
  String get telegramCountryCodeLabel;

  /// No description provided for @telegramPhoneNumber.
  ///
  /// In ru, this message translates to:
  /// **'Номер телефона'**
  String get telegramPhoneNumber;

  /// No description provided for @telegramGetCode.
  ///
  /// In ru, this message translates to:
  /// **'Получить код'**
  String get telegramGetCode;

  /// No description provided for @telegramRefreshQr.
  ///
  /// In ru, this message translates to:
  /// **'Обновить QR-код'**
  String get telegramRefreshQr;

  /// No description provided for @telegramSignUp.
  ///
  /// In ru, this message translates to:
  /// **'Зарегистрироваться'**
  String get telegramSignUp;

  /// No description provided for @telegramEnterStoreName.
  ///
  /// In ru, this message translates to:
  /// **'Введите название магазина'**
  String get telegramEnterStoreName;

  /// No description provided for @telegramInvalidBinIin.
  ///
  /// In ru, this message translates to:
  /// **'Введите корректный БИН/ИИН (12 цифр)'**
  String get telegramInvalidBinIin;

  /// No description provided for @telegramInvalidCode.
  ///
  /// In ru, this message translates to:
  /// **'Введите корректный код'**
  String get telegramInvalidCode;

  /// No description provided for @telegramEnterPassword.
  ///
  /// In ru, this message translates to:
  /// **'Введите пароль'**
  String get telegramEnterPassword;

  /// No description provided for @telegramCodeResent.
  ///
  /// In ru, this message translates to:
  /// **'Код отправлен повторно'**
  String get telegramCodeResent;

  /// No description provided for @telegramEnterName.
  ///
  /// In ru, this message translates to:
  /// **'Введите имя'**
  String get telegramEnterName;

  /// No description provided for @telegramManageAccount.
  ///
  /// In ru, this message translates to:
  /// **'Управление аккаунтом'**
  String get telegramManageAccount;

  /// No description provided for @telegramNotificationsSection.
  ///
  /// In ru, this message translates to:
  /// **'Уведомления'**
  String get telegramNotificationsSection;

  /// No description provided for @telegramNotificationsDesc.
  ///
  /// In ru, this message translates to:
  /// **'Получать уведомления о продажах, сменах и др.'**
  String get telegramNotificationsDesc;

  /// No description provided for @telegramNotifySales.
  ///
  /// In ru, this message translates to:
  /// **'Уведомления о продажах'**
  String get telegramNotifySales;

  /// No description provided for @telegramNotifySalesDesc.
  ///
  /// In ru, this message translates to:
  /// **'Крупные продажи, возвраты'**
  String get telegramNotifySalesDesc;

  /// No description provided for @telegramNotifyShifts.
  ///
  /// In ru, this message translates to:
  /// **'Уведомления о сменах'**
  String get telegramNotifyShifts;

  /// No description provided for @telegramNotifyShiftsDesc.
  ///
  /// In ru, this message translates to:
  /// **'Открытие и закрытие смен'**
  String get telegramNotifyShiftsDesc;

  /// No description provided for @telegramNotifyCritical.
  ///
  /// In ru, this message translates to:
  /// **'Критические уведомления'**
  String get telegramNotifyCritical;

  /// No description provided for @telegramNotifyCriticalDesc.
  ///
  /// In ru, this message translates to:
  /// **'Ошибки, проблемы с OFD'**
  String get telegramNotifyCriticalDesc;

  /// No description provided for @telegramNotifyStock.
  ///
  /// In ru, this message translates to:
  /// **'Уведомления об остатках'**
  String get telegramNotifyStock;

  /// No description provided for @telegramNotifyStockDesc.
  ///
  /// In ru, this message translates to:
  /// **'Дефицит товаров'**
  String get telegramNotifyStockDesc;

  /// No description provided for @telegramSyncSettings.
  ///
  /// In ru, this message translates to:
  /// **'Настройки синхронизации'**
  String get telegramSyncSettings;

  /// No description provided for @telegramAutoSyncDesc.
  ///
  /// In ru, this message translates to:
  /// **'Автоматически синхронизировать данные'**
  String get telegramAutoSyncDesc;

  /// No description provided for @telegramSyncInterval1min.
  ///
  /// In ru, this message translates to:
  /// **'1 минута'**
  String get telegramSyncInterval1min;

  /// No description provided for @telegramSyncInterval5min.
  ///
  /// In ru, this message translates to:
  /// **'5 минут'**
  String get telegramSyncInterval5min;

  /// No description provided for @telegramSyncInterval15min.
  ///
  /// In ru, this message translates to:
  /// **'15 минут'**
  String get telegramSyncInterval15min;

  /// No description provided for @telegramSyncInterval30min.
  ///
  /// In ru, this message translates to:
  /// **'30 минут'**
  String get telegramSyncInterval30min;

  /// No description provided for @telegramSyncInterval1hour.
  ///
  /// In ru, this message translates to:
  /// **'1 час'**
  String get telegramSyncInterval1hour;

  /// No description provided for @telegramSystemChannels.
  ///
  /// In ru, this message translates to:
  /// **'Системные каналы'**
  String get telegramSystemChannels;

  /// No description provided for @telegramRefresh.
  ///
  /// In ru, this message translates to:
  /// **'Обновить'**
  String get telegramRefresh;

  /// No description provided for @telegramChannelsNotConnected.
  ///
  /// In ru, this message translates to:
  /// **'Каналы не подключены.\nВойдите в Telegram для автоматического создания.'**
  String get telegramChannelsNotConnected;

  /// No description provided for @telegramChannelsConnected.
  ///
  /// In ru, this message translates to:
  /// **'{connected} из {total} каналов подключено'**
  String telegramChannelsConnected(int connected, int total);

  /// No description provided for @telegramChannelsLoadError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка загрузки каналов: {error}'**
  String telegramChannelsLoadError(String error);

  /// No description provided for @telegramForceSyncDesc.
  ///
  /// In ru, this message translates to:
  /// **'Синхронизировать все данные сейчас'**
  String get telegramForceSyncDesc;

  /// No description provided for @telegramFullSyncDesc.
  ///
  /// In ru, this message translates to:
  /// **'Сбросить и пересинхронизировать всё'**
  String get telegramFullSyncDesc;

  /// No description provided for @telegramRecreateChannelsDesc.
  ///
  /// In ru, this message translates to:
  /// **'Пересоздать системные каналы'**
  String get telegramRecreateChannelsDesc;

  /// No description provided for @telegramLogoutDesc.
  ///
  /// In ru, this message translates to:
  /// **'Отключить Telegram интеграцию'**
  String get telegramLogoutDesc;

  /// No description provided for @telegramFullSyncWarning.
  ///
  /// In ru, this message translates to:
  /// **'Это сбросит все временные метки синхронизации и перезагрузит все данные. Операция может занять продолжительное время.'**
  String get telegramFullSyncWarning;

  /// No description provided for @telegramRecreateChannelsWarning.
  ///
  /// In ru, this message translates to:
  /// **'Это действие пересоздаст все системные каналы. Существующие данные в каналах будут потеряны.'**
  String get telegramRecreateChannelsWarning;

  /// No description provided for @telegramLogoutWarning.
  ///
  /// In ru, this message translates to:
  /// **'Вы уверены, что хотите выйти? Синхронизация и уведомления будут отключены.'**
  String get telegramLogoutWarning;

  /// No description provided for @telegramChannelsRecreated.
  ///
  /// In ru, this message translates to:
  /// **'Каналы пересозданы'**
  String get telegramChannelsRecreated;

  /// No description provided for @telegramConnectedStatus.
  ///
  /// In ru, this message translates to:
  /// **'Подключено'**
  String get telegramConnectedStatus;

  /// No description provided for @telegramNotConnected.
  ///
  /// In ru, this message translates to:
  /// **'Не подключено'**
  String get telegramNotConnected;

  /// No description provided for @telegramAccountLabel.
  ///
  /// In ru, this message translates to:
  /// **'Telegram аккаунт'**
  String get telegramAccountLabel;

  /// No description provided for @telegramLoginForSync.
  ///
  /// In ru, this message translates to:
  /// **'Войдите для синхронизации данных'**
  String get telegramLoginForSync;

  /// No description provided for @channelDescSystemEvents.
  ///
  /// In ru, this message translates to:
  /// **'Системные события'**
  String get channelDescSystemEvents;

  /// No description provided for @channelDescSales.
  ///
  /// In ru, this message translates to:
  /// **'Лента продаж'**
  String get channelDescSales;

  /// No description provided for @channelDescAlerts.
  ///
  /// In ru, this message translates to:
  /// **'Критические уведомления'**
  String get channelDescAlerts;

  /// No description provided for @channelDescReports.
  ///
  /// In ru, this message translates to:
  /// **'Отчёты и сводки'**
  String get channelDescReports;

  /// No description provided for @channelDescSync.
  ///
  /// In ru, this message translates to:
  /// **'Синхронизация данных'**
  String get channelDescSync;

  /// No description provided for @channelDescFiscal.
  ///
  /// In ru, this message translates to:
  /// **'Фискальные события'**
  String get channelDescFiscal;

  /// No description provided for @channelDescStaffChat.
  ///
  /// In ru, this message translates to:
  /// **'Чат сотрудников'**
  String get channelDescStaffChat;

  /// No description provided for @channelDescDataExchange.
  ///
  /// In ru, this message translates to:
  /// **'Обмен данными'**
  String get channelDescDataExchange;

  /// No description provided for @channelDescTerminalStatus.
  ///
  /// In ru, this message translates to:
  /// **'Статус терминала'**
  String get channelDescTerminalStatus;

  /// No description provided for @channelDescBackup.
  ///
  /// In ru, this message translates to:
  /// **'Резервные копии БД'**
  String get channelDescBackup;

  /// No description provided for @chatNoConnectionBanner.
  ///
  /// In ru, this message translates to:
  /// **'Нет соединения. Сообщения будут отправлены при восстановлении.'**
  String get chatNoConnectionBanner;

  /// No description provided for @chatLinkTelegramForId.
  ///
  /// In ru, this message translates to:
  /// **'Привяжите Telegram для идентификации в чате'**
  String get chatLinkTelegramForId;

  /// No description provided for @chatSendError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка отправки: {error}'**
  String chatSendError(String error);

  /// No description provided for @chatFoundMessages.
  ///
  /// In ru, this message translates to:
  /// **'Найдено {count} сообщений'**
  String chatFoundMessages(int count);

  /// No description provided for @chatNoResults.
  ///
  /// In ru, this message translates to:
  /// **'Ничего не найдено'**
  String get chatNoResults;

  /// No description provided for @chatCopyUidInstructions.
  ///
  /// In ru, this message translates to:
  /// **'Скопируйте UID для использования в других системах'**
  String get chatCopyUidInstructions;

  /// No description provided for @chatUidExample.
  ///
  /// In ru, this message translates to:
  /// **'Например: telepos@pos-1'**
  String get chatUidExample;

  /// No description provided for @chatServiceUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Сервис недоступен'**
  String get chatServiceUnavailable;

  /// No description provided for @chatTelegramLinked.
  ///
  /// In ru, this message translates to:
  /// **'Telegram успешно привязан'**
  String get chatTelegramLinked;

  /// No description provided for @additionalLogout.
  ///
  /// In ru, this message translates to:
  /// **'Выход'**
  String get additionalLogout;

  /// No description provided for @additionalLockCashier.
  ///
  /// In ru, this message translates to:
  /// **'Блокировка'**
  String get additionalLockCashier;

  /// No description provided for @additionalPrinterAction.
  ///
  /// In ru, this message translates to:
  /// **'Принтер'**
  String get additionalPrinterAction;

  /// No description provided for @additionalPrintLastReceipt.
  ///
  /// In ru, this message translates to:
  /// **'Последний чек'**
  String get additionalPrintLastReceipt;

  /// No description provided for @additionalSyncAction.
  ///
  /// In ru, this message translates to:
  /// **'Синхронизация'**
  String get additionalSyncAction;

  /// No description provided for @additionalCheckPrice.
  ///
  /// In ru, this message translates to:
  /// **'Проверка цены'**
  String get additionalCheckPrice;

  /// No description provided for @additionalMinimize.
  ///
  /// In ru, this message translates to:
  /// **'Свернуть'**
  String get additionalMinimize;

  /// No description provided for @additionalCustomers.
  ///
  /// In ru, this message translates to:
  /// **'Покупатели'**
  String get additionalCustomers;

  /// No description provided for @additionalUpdateAction.
  ///
  /// In ru, this message translates to:
  /// **'Обновление'**
  String get additionalUpdateAction;

  /// No description provided for @additionalExtraPrinter.
  ///
  /// In ru, this message translates to:
  /// **'Доп. принтер'**
  String get additionalExtraPrinter;

  /// No description provided for @additionalSupplyAction.
  ///
  /// In ru, this message translates to:
  /// **'Приёмка'**
  String get additionalSupplyAction;

  /// No description provided for @additionalLanguageAction.
  ///
  /// In ru, this message translates to:
  /// **'Язык'**
  String get additionalLanguageAction;

  /// No description provided for @additionalKaspiPos.
  ///
  /// In ru, this message translates to:
  /// **'Kaspi POS'**
  String get additionalKaspiPos;

  /// No description provided for @additionalPrinterEscPos.
  ///
  /// In ru, this message translates to:
  /// **'Термопринтер ESC/POS'**
  String get additionalPrinterEscPos;

  /// No description provided for @additionalPrinterNotConfigured.
  ///
  /// In ru, this message translates to:
  /// **'Принтер не настроен'**
  String get additionalPrinterNotConfigured;

  /// No description provided for @additionalPrinterWifi.
  ///
  /// In ru, this message translates to:
  /// **'Wi-Fi принтер'**
  String get additionalPrinterWifi;

  /// No description provided for @additionalPrinterWifiDesc.
  ///
  /// In ru, this message translates to:
  /// **'Подключение по IP'**
  String get additionalPrinterWifiDesc;

  /// No description provided for @additionalPrinterBluetooth.
  ///
  /// In ru, this message translates to:
  /// **'Bluetooth принтер'**
  String get additionalPrinterBluetooth;

  /// No description provided for @additionalPrinterBluetoothDesc.
  ///
  /// In ru, this message translates to:
  /// **'Поиск устройств'**
  String get additionalPrinterBluetoothDesc;

  /// No description provided for @additionalPrinterUsb.
  ///
  /// In ru, this message translates to:
  /// **'USB принтер'**
  String get additionalPrinterUsb;

  /// No description provided for @additionalPrinterSystem.
  ///
  /// In ru, this message translates to:
  /// **'Системный принтер'**
  String get additionalPrinterSystem;

  /// No description provided for @additionalPrinterDisconnected.
  ///
  /// In ru, this message translates to:
  /// **'Принтер отключён'**
  String get additionalPrinterDisconnected;

  /// No description provided for @additionalPrinterIpLabel.
  ///
  /// In ru, this message translates to:
  /// **'IP'**
  String get additionalPrinterIpLabel;

  /// No description provided for @additionalPrinterEnterIp.
  ///
  /// In ru, this message translates to:
  /// **'Введите IP адрес'**
  String get additionalPrinterEnterIp;

  /// No description provided for @additionalPrinterConnecting.
  ///
  /// In ru, this message translates to:
  /// **'Подключение к {address}...'**
  String additionalPrinterConnecting(String address);

  /// No description provided for @additionalPrinterConnectingUsb.
  ///
  /// In ru, this message translates to:
  /// **'Подключение USB принтера...'**
  String get additionalPrinterConnectingUsb;

  /// No description provided for @additionalPrinterNotConnected.
  ///
  /// In ru, this message translates to:
  /// **'Принтер не подключён'**
  String get additionalPrinterNotConnected;

  /// No description provided for @additionalPrintingLastReceipt.
  ///
  /// In ru, this message translates to:
  /// **'Печать последнего чека...'**
  String get additionalPrintingLastReceipt;

  /// No description provided for @additionalTestReceiptTitle.
  ///
  /// In ru, this message translates to:
  /// **'=== ТЕСТОВЫЙ ЧЕК ==='**
  String get additionalTestReceiptTitle;

  /// No description provided for @additionalReceiptPrinted.
  ///
  /// In ru, this message translates to:
  /// **'Чек напечатан'**
  String get additionalReceiptPrinted;

  /// No description provided for @additionalPriceSearching.
  ///
  /// In ru, this message translates to:
  /// **'Поиск: {query}'**
  String additionalPriceSearching(String query);

  /// No description provided for @additionalMinimizing.
  ///
  /// In ru, this message translates to:
  /// **'Сворачивание окна...'**
  String get additionalMinimizing;

  /// No description provided for @additionalLatestVersion.
  ///
  /// In ru, this message translates to:
  /// **'У вас установлена последняя версия'**
  String get additionalLatestVersion;

  /// No description provided for @additionalExtraPrinterTitle.
  ///
  /// In ru, this message translates to:
  /// **'Дополнительный принтер'**
  String get additionalExtraPrinterTitle;

  /// No description provided for @additionalExtraPrinterUsedFor.
  ///
  /// In ru, this message translates to:
  /// **'Дополнительный принтер используется для:'**
  String get additionalExtraPrinterUsedFor;

  /// No description provided for @additionalExtraPrinterLabels.
  ///
  /// In ru, this message translates to:
  /// **'Печать этикеток'**
  String get additionalExtraPrinterLabels;

  /// No description provided for @additionalExtraPrinterKitchen.
  ///
  /// In ru, this message translates to:
  /// **'Печать на кухню'**
  String get additionalExtraPrinterKitchen;

  /// No description provided for @additionalExtraPrinterDuplicate.
  ///
  /// In ru, this message translates to:
  /// **'Дубликат чека'**
  String get additionalExtraPrinterDuplicate;

  /// No description provided for @additionalKaspiPosTitle.
  ///
  /// In ru, this message translates to:
  /// **'Kaspi POS'**
  String get additionalKaspiPosTitle;

  /// No description provided for @additionalKaspiPosDesc.
  ///
  /// In ru, this message translates to:
  /// **'Терминал Kaspi для приёма платежей.'**
  String get additionalKaspiPosDesc;

  /// No description provided for @additionalKaspiPosNotConnected.
  ///
  /// In ru, this message translates to:
  /// **'Статус: Не подключён'**
  String get additionalKaspiPosNotConnected;

  /// No description provided for @additionalPrinterConnectedName.
  ///
  /// In ru, this message translates to:
  /// **'Принтер подключён: {name}'**
  String additionalPrinterConnectedName(String name);

  /// No description provided for @additionalErrorWithMessage.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка: {message}'**
  String additionalErrorWithMessage(String message);

  /// No description provided for @additionalPrinterUsbNotSupported.
  ///
  /// In ru, this message translates to:
  /// **'USB принтеры не поддерживаются'**
  String get additionalPrinterUsbNotSupported;

  /// No description provided for @additionalPrinterUsbConnected.
  ///
  /// In ru, this message translates to:
  /// **'USB принтер подключён'**
  String get additionalPrinterUsbConnected;

  /// No description provided for @additionalBarcodeLabel.
  ///
  /// In ru, this message translates to:
  /// **'Штрихкод'**
  String get additionalBarcodeLabel;

  /// No description provided for @additionalBarcodeHint.
  ///
  /// In ru, this message translates to:
  /// **'Отсканируйте или введите'**
  String get additionalBarcodeHint;

  /// No description provided for @additionalTestReceiptProduct.
  ///
  /// In ru, this message translates to:
  /// **'Товар {number}'**
  String additionalTestReceiptProduct(String number);

  /// No description provided for @additionalTestReceiptTotal.
  ///
  /// In ru, this message translates to:
  /// **'ИТОГО:'**
  String get additionalTestReceiptTotal;

  /// No description provided for @additionalTestReceiptThankYou.
  ///
  /// In ru, this message translates to:
  /// **'Спасибо за покупку!'**
  String get additionalTestReceiptThankYou;

  /// No description provided for @langRussian.
  ///
  /// In ru, this message translates to:
  /// **'Русский'**
  String get langRussian;

  /// No description provided for @langEnglish.
  ///
  /// In ru, this message translates to:
  /// **'English'**
  String get langEnglish;

  /// No description provided for @langKazakh.
  ///
  /// In ru, this message translates to:
  /// **'Қазақша'**
  String get langKazakh;

  /// No description provided for @langKyrgyz.
  ///
  /// In ru, this message translates to:
  /// **'Кыргызча'**
  String get langKyrgyz;

  /// No description provided for @langUzbek.
  ///
  /// In ru, this message translates to:
  /// **'O\'zbekcha'**
  String get langUzbek;

  /// No description provided for @transportFullSyncWarning.
  ///
  /// In ru, this message translates to:
  /// **'Это сбросит все метки синхронизации и перезагрузит все данные. Это может занять продолжительное время. Продолжить?'**
  String get transportFullSyncWarning;

  /// No description provided for @transportSyncAbout.
  ///
  /// In ru, this message translates to:
  /// **'О синхронизации'**
  String get transportSyncAbout;

  /// No description provided for @transportSyncStateError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка загрузки состояния синхронизации: {error}'**
  String transportSyncStateError(String error);

  /// No description provided for @transportSyncInfoDialog.
  ///
  /// In ru, this message translates to:
  /// **'Каждый тип данных синхронизируется независимо. Передаются только элементы, изменённые после последней синхронизации.\n\nИнтервал: 5 минут (по умолчанию)\nДанные шифруются AES-256-GCM перед передачей.'**
  String get transportSyncInfoDialog;

  /// No description provided for @transportSyncNever.
  ///
  /// In ru, this message translates to:
  /// **'Никогда'**
  String get transportSyncNever;

  /// No description provided for @transportModeDescription.
  ///
  /// In ru, this message translates to:
  /// **'Выберите способ обмена данными с сервером'**
  String get transportModeDescription;

  /// No description provided for @transportModeRest.
  ///
  /// In ru, this message translates to:
  /// **'REST API'**
  String get transportModeRest;

  /// No description provided for @transportModeRestDesc.
  ///
  /// In ru, this message translates to:
  /// **'Классическое HTTP/WebSocket подключение'**
  String get transportModeRestDesc;

  /// No description provided for @transportModeTelegram.
  ///
  /// In ru, this message translates to:
  /// **'Telegram'**
  String get transportModeTelegram;

  /// No description provided for @transportModeTelegramDesc.
  ///
  /// In ru, this message translates to:
  /// **'Telegram как транспортный слой'**
  String get transportModeTelegramDesc;

  /// No description provided for @transportModeHybrid.
  ///
  /// In ru, this message translates to:
  /// **'Гибридный'**
  String get transportModeHybrid;

  /// No description provided for @transportModeHybridDesc.
  ///
  /// In ru, this message translates to:
  /// **'Telegram основной, REST как резерв'**
  String get transportModeHybridDesc;

  /// No description provided for @transportModeRecommended.
  ///
  /// In ru, this message translates to:
  /// **'Рекомендуется'**
  String get transportModeRecommended;

  /// No description provided for @transportSyncIntervalMinutes.
  ///
  /// In ru, this message translates to:
  /// **'{minutes} минут'**
  String transportSyncIntervalMinutes(int minutes);

  /// No description provided for @transportSyncOnConnectivity.
  ///
  /// In ru, this message translates to:
  /// **'Синхронизировать при восстановлении сети'**
  String get transportSyncOnConnectivity;

  /// No description provided for @transportSyncIntervalOption.
  ///
  /// In ru, this message translates to:
  /// **'{minutes, plural, one{{minutes} минута} few{{minutes} минуты} other{{minutes} минут}}'**
  String transportSyncIntervalOption(int minutes);

  /// No description provided for @transportEnableQueue.
  ///
  /// In ru, this message translates to:
  /// **'Очередь операций'**
  String get transportEnableQueue;

  /// No description provided for @transportEnableQueueDesc.
  ///
  /// In ru, this message translates to:
  /// **'Буферизация операций при отсутствии сети'**
  String get transportEnableQueueDesc;

  /// No description provided for @transportMaxQueueSize.
  ///
  /// In ru, this message translates to:
  /// **'Размер очереди'**
  String get transportMaxQueueSize;

  /// No description provided for @transportQueueSizeStatus.
  ///
  /// In ru, this message translates to:
  /// **'{size} операций'**
  String transportQueueSizeStatus(int size);

  /// No description provided for @transportAutoCleanup.
  ///
  /// In ru, this message translates to:
  /// **'Автоочистка'**
  String get transportAutoCleanup;

  /// No description provided for @transportAutoCleanupDesc.
  ///
  /// In ru, this message translates to:
  /// **'Удалять завершённые операции через 7 дней'**
  String get transportAutoCleanupDesc;

  /// No description provided for @transportNotifyChanges.
  ///
  /// In ru, this message translates to:
  /// **'Смена транспорта'**
  String get transportNotifyChanges;

  /// No description provided for @transportNotifyChangesDesc.
  ///
  /// In ru, this message translates to:
  /// **'Уведомлять при смене режима транспорта'**
  String get transportNotifyChangesDesc;

  /// No description provided for @transportNotifySyncErrors.
  ///
  /// In ru, this message translates to:
  /// **'Ошибки синхронизации'**
  String get transportNotifySyncErrors;

  /// No description provided for @transportNotifySyncErrorsDesc.
  ///
  /// In ru, this message translates to:
  /// **'Уведомлять об ошибках синхронизации'**
  String get transportNotifySyncErrorsDesc;

  /// No description provided for @transportNotifyOfflineOnline.
  ///
  /// In ru, this message translates to:
  /// **'Связь'**
  String get transportNotifyOfflineOnline;

  /// No description provided for @transportNotifyConnectivityDesc.
  ///
  /// In ru, this message translates to:
  /// **'Уведомлять о смене подключения'**
  String get transportNotifyConnectivityDesc;

  /// No description provided for @transportNotifyQueueFull.
  ///
  /// In ru, this message translates to:
  /// **'Очередь полна'**
  String get transportNotifyQueueFull;

  /// No description provided for @transportNotifyQueueFullDesc.
  ///
  /// In ru, this message translates to:
  /// **'Уведомлять при заполнении очереди'**
  String get transportNotifyQueueFullDesc;

  /// No description provided for @saleErrorInitiation.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка инициации продажи: {error}'**
  String saleErrorInitiation(String error);

  /// No description provided for @saleErrorNotInitialized.
  ///
  /// In ru, this message translates to:
  /// **'Продажа не инициализирована'**
  String get saleErrorNotInitialized;

  /// No description provided for @saleErrorEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Чек пуст'**
  String get saleErrorEmpty;

  /// No description provided for @saleErrorCompletion.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка завершения продажи: {error}'**
  String saleErrorCompletion(String error);

  /// No description provided for @saleErrorSearch.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка поиска: {error}'**
  String saleErrorSearch(String error);

  /// No description provided for @saleErrorDeferred.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка отложения чека: {error}'**
  String saleErrorDeferred(String error);

  /// No description provided for @saleErrorDeferredNotFound.
  ///
  /// In ru, this message translates to:
  /// **'Отложенный чек не найден'**
  String get saleErrorDeferredNotFound;

  /// No description provided for @saleErrorLoadingDeferred.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка загрузки отложенного чека: {error}'**
  String saleErrorLoadingDeferred(String error);

  /// No description provided for @paymentCustomerDefault.
  ///
  /// In ru, this message translates to:
  /// **'Клиент'**
  String get paymentCustomerDefault;

  /// No description provided for @paymentErrorFormation.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось сформировать платёж. Проверьте настройки счетов.'**
  String get paymentErrorFormation;

  /// No description provided for @paymentErrorSaving.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка сохранения продажи'**
  String get paymentErrorSaving;

  /// No description provided for @paymentErrorProcessing.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка обработки платежа: {error}'**
  String paymentErrorProcessing(String error);

  /// No description provided for @paymentAccountDefault.
  ///
  /// In ru, this message translates to:
  /// **'Счёт {id}'**
  String paymentAccountDefault(int id);

  /// No description provided for @refundErrorReceiptNotFound.
  ///
  /// In ru, this message translates to:
  /// **'Чек #{number} не найден'**
  String refundErrorReceiptNotFound(String number);

  /// No description provided for @refundErrorLoadingReceipt.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка загрузки чека: {error}'**
  String refundErrorLoadingReceipt(String error);

  /// No description provided for @refundErrorSearch.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка поиска: {error}'**
  String refundErrorSearch(String error);

  /// No description provided for @refundErrorProductNotFound.
  ///
  /// In ru, this message translates to:
  /// **'Товар не найден'**
  String get refundErrorProductNotFound;

  /// No description provided for @refundErrorNotAuthenticated.
  ///
  /// In ru, this message translates to:
  /// **'Пользователь не авторизован'**
  String get refundErrorNotAuthenticated;

  /// No description provided for @refundErrorProcessing.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка возврата: {error}'**
  String refundErrorProcessing(String error);

  /// No description provided for @shiftErrorLoadingData.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка загрузки данных смены: {error}'**
  String shiftErrorLoadingData(String error);

  /// No description provided for @shiftErrorOpening.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка открытия смены: {error}'**
  String shiftErrorOpening(String error);

  /// No description provided for @shiftErrorClosing.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка закрытия смены: {error}'**
  String shiftErrorClosing(String error);

  /// No description provided for @shiftErrorPrinting.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка печати Z-отчёта: {error}'**
  String shiftErrorPrinting(String error);

  /// No description provided for @cashOpTypeInvestment.
  ///
  /// In ru, this message translates to:
  /// **'Внесение'**
  String get cashOpTypeInvestment;

  /// No description provided for @cashOpTypeExpense.
  ///
  /// In ru, this message translates to:
  /// **'Расход'**
  String get cashOpTypeExpense;

  /// No description provided for @cashOpTypeDividend.
  ///
  /// In ru, this message translates to:
  /// **'Изъятие'**
  String get cashOpTypeDividend;

  /// No description provided for @supplyNoName.
  ///
  /// In ru, this message translates to:
  /// **'Без имени'**
  String get supplyNoName;

  /// No description provided for @supplyNoTitle.
  ///
  /// In ru, this message translates to:
  /// **'Без названия'**
  String get supplyNoTitle;

  /// No description provided for @supplyErrorSupplierNotFound.
  ///
  /// In ru, this message translates to:
  /// **'Поставщик не найден'**
  String get supplyErrorSupplierNotFound;

  /// No description provided for @supplyErrorSelectingSupplier.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка выбора поставщика: {error}'**
  String supplyErrorSelectingSupplier(String error);

  /// No description provided for @supplyErrorAccountNotFound.
  ///
  /// In ru, this message translates to:
  /// **'Счёт не найден'**
  String get supplyErrorAccountNotFound;

  /// No description provided for @supplyErrorSelectingAccount.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка выбора счёта: {error}'**
  String supplyErrorSelectingAccount(String error);

  /// No description provided for @supplyErrorAddingProduct.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка добавления товара: {error}'**
  String supplyErrorAddingProduct(String error);

  /// No description provided for @supplyErrorProductNotFound.
  ///
  /// In ru, this message translates to:
  /// **'Товар не найден'**
  String get supplyErrorProductNotFound;

  /// No description provided for @supplyErrorMissingFields.
  ///
  /// In ru, this message translates to:
  /// **'Заполните все обязательные поля'**
  String get supplyErrorMissingFields;

  /// No description provided for @supplyErrorSaving.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка сохранения: {error}'**
  String supplyErrorSaving(String error);

  /// No description provided for @historyErrorLoading.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка загрузки истории: {error}'**
  String historyErrorLoading(String error);

  /// No description provided for @syncTypeProducts.
  ///
  /// In ru, this message translates to:
  /// **'Товары'**
  String get syncTypeProducts;

  /// No description provided for @syncTypePrices.
  ///
  /// In ru, this message translates to:
  /// **'Цены'**
  String get syncTypePrices;

  /// No description provided for @syncTypeCategories.
  ///
  /// In ru, this message translates to:
  /// **'Категории'**
  String get syncTypeCategories;

  /// No description provided for @syncTypeAgents.
  ///
  /// In ru, this message translates to:
  /// **'Контрагенты'**
  String get syncTypeAgents;

  /// No description provided for @syncTypeConfig.
  ///
  /// In ru, this message translates to:
  /// **'Настройки'**
  String get syncTypeConfig;

  /// No description provided for @syncTypeSales.
  ///
  /// In ru, this message translates to:
  /// **'Продажи'**
  String get syncTypeSales;

  /// No description provided for @syncTypeRefunds.
  ///
  /// In ru, this message translates to:
  /// **'Возвраты'**
  String get syncTypeRefunds;

  /// No description provided for @syncTypeCashOps.
  ///
  /// In ru, this message translates to:
  /// **'Кассовые операции'**
  String get syncTypeCashOps;

  /// No description provided for @syncTypeShifts.
  ///
  /// In ru, this message translates to:
  /// **'Смены'**
  String get syncTypeShifts;

  /// No description provided for @syncTypeSupplies.
  ///
  /// In ru, this message translates to:
  /// **'Приёмки'**
  String get syncTypeSupplies;

  /// No description provided for @syncStepPreparing.
  ///
  /// In ru, this message translates to:
  /// **'Подготовка...'**
  String get syncStepPreparing;

  /// No description provided for @syncStepUploading.
  ///
  /// In ru, this message translates to:
  /// **'Выгрузка: {type}'**
  String syncStepUploading(String type);

  /// No description provided for @syncStepDownloading.
  ///
  /// In ru, this message translates to:
  /// **'Загрузка: {type}'**
  String syncStepDownloading(String type);

  /// No description provided for @syncCompleted.
  ///
  /// In ru, this message translates to:
  /// **'Синхронизация завершена'**
  String get syncCompleted;

  /// No description provided for @loginErrorNoUsers.
  ///
  /// In ru, this message translates to:
  /// **'Нет зарегистрированных пользователей'**
  String get loginErrorNoUsers;

  /// No description provided for @loginErrorLoadingData.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка загрузки данных: {error}'**
  String loginErrorLoadingData(String error);

  /// No description provided for @loginErrorSelectUser.
  ///
  /// In ru, this message translates to:
  /// **'Выберите пользователя'**
  String get loginErrorSelectUser;

  /// No description provided for @loginErrorIncompletePin.
  ///
  /// In ru, this message translates to:
  /// **'Введите PIN-код (минимум 4 цифры)'**
  String get loginErrorIncompletePin;

  /// No description provided for @loginErrorNoRsaKey.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка: RSA ключ не настроен. Обратитесь к администратору.'**
  String get loginErrorNoRsaKey;

  /// No description provided for @loginErrorWrongPin.
  ///
  /// In ru, this message translates to:
  /// **'Неверный PIN-код'**
  String get loginErrorWrongPin;

  /// No description provided for @loginErrorSystemTime.
  ///
  /// In ru, this message translates to:
  /// **'Системное время некорректно. Проверьте настройки даты и времени.'**
  String get loginErrorSystemTime;

  /// No description provided for @receiptLabelBin.
  ///
  /// In ru, this message translates to:
  /// **'БИН:'**
  String get receiptLabelBin;

  /// No description provided for @receiptLabelPhone.
  ///
  /// In ru, this message translates to:
  /// **'Тел:'**
  String get receiptLabelPhone;

  /// No description provided for @receiptLabelReceiptNo.
  ///
  /// In ru, this message translates to:
  /// **'Чек №:'**
  String get receiptLabelReceiptNo;

  /// No description provided for @receiptLabelPosId.
  ///
  /// In ru, this message translates to:
  /// **'Касса:'**
  String get receiptLabelPosId;

  /// No description provided for @receiptLabelDate.
  ///
  /// In ru, this message translates to:
  /// **'Дата:'**
  String get receiptLabelDate;

  /// No description provided for @receiptLabelCashier.
  ///
  /// In ru, this message translates to:
  /// **'Кассир:'**
  String get receiptLabelCashier;

  /// No description provided for @receiptLabelTable.
  ///
  /// In ru, this message translates to:
  /// **'Стол:'**
  String get receiptLabelTable;

  /// No description provided for @receiptLabelWaiter.
  ///
  /// In ru, this message translates to:
  /// **'Официант:'**
  String get receiptLabelWaiter;

  /// No description provided for @receiptLabelGuests.
  ///
  /// In ru, this message translates to:
  /// **'Гостей:'**
  String get receiptLabelGuests;

  /// No description provided for @receiptLabelCustomer.
  ///
  /// In ru, this message translates to:
  /// **'Клиент:'**
  String get receiptLabelCustomer;

  /// No description provided for @receiptLabelSubtotal.
  ///
  /// In ru, this message translates to:
  /// **'Подытог:'**
  String get receiptLabelSubtotal;

  /// No description provided for @receiptLabelDiscount.
  ///
  /// In ru, this message translates to:
  /// **'Скидка:'**
  String get receiptLabelDiscount;

  /// No description provided for @receiptLabelServiceCharge.
  ///
  /// In ru, this message translates to:
  /// **'Сервис. сбор:'**
  String get receiptLabelServiceCharge;

  /// No description provided for @receiptLabelTotal.
  ///
  /// In ru, this message translates to:
  /// **'ИТОГО:'**
  String get receiptLabelTotal;

  /// No description provided for @receiptLabelVat.
  ///
  /// In ru, this message translates to:
  /// **'в т.ч. НДС {percent}%:'**
  String receiptLabelVat(String percent);

  /// No description provided for @receiptLabelCash.
  ///
  /// In ru, this message translates to:
  /// **'Наличные:'**
  String get receiptLabelCash;

  /// No description provided for @receiptLabelCard.
  ///
  /// In ru, this message translates to:
  /// **'Карта:'**
  String get receiptLabelCard;

  /// No description provided for @receiptLabelChange.
  ///
  /// In ru, this message translates to:
  /// **'Сдача:'**
  String get receiptLabelChange;

  /// No description provided for @receiptLabelCheckReceipt.
  ///
  /// In ru, this message translates to:
  /// **'Проверить чек:'**
  String get receiptLabelCheckReceipt;

  /// No description provided for @receiptLabelItemName.
  ///
  /// In ru, this message translates to:
  /// **'Наименование'**
  String get receiptLabelItemName;

  /// No description provided for @receiptLabelQty.
  ///
  /// In ru, this message translates to:
  /// **'Кол'**
  String get receiptLabelQty;

  /// No description provided for @receiptLabelPrice.
  ///
  /// In ru, this message translates to:
  /// **'Цена'**
  String get receiptLabelPrice;

  /// No description provided for @receiptLabelAmount.
  ///
  /// In ru, this message translates to:
  /// **'Сумма'**
  String get receiptLabelAmount;

  /// No description provided for @receiptLabelItemDiscount.
  ///
  /// In ru, this message translates to:
  /// **'Скидка:'**
  String get receiptLabelItemDiscount;

  /// No description provided for @receiptLabelFiscalBin.
  ///
  /// In ru, this message translates to:
  /// **'БИН:'**
  String get receiptLabelFiscalBin;

  /// No description provided for @receiptLabelFiscalNo.
  ///
  /// In ru, this message translates to:
  /// **'ФН:'**
  String get receiptLabelFiscalNo;

  /// No description provided for @receiptLabelFiscalSign.
  ///
  /// In ru, this message translates to:
  /// **'ФП:'**
  String get receiptLabelFiscalSign;

  /// No description provided for @receiptLabelVatCertificate.
  ///
  /// In ru, this message translates to:
  /// **'НДС:'**
  String get receiptLabelVatCertificate;

  /// No description provided for @receiptLabelOfflineMode.
  ///
  /// In ru, this message translates to:
  /// **'*** ОФФЛАЙН ***'**
  String get receiptLabelOfflineMode;

  /// No description provided for @receiptLabelRefundHeader.
  ///
  /// In ru, this message translates to:
  /// **'*** ВОЗВРАТ ***'**
  String get receiptLabelRefundHeader;

  /// No description provided for @receiptLabelRefundNo.
  ///
  /// In ru, this message translates to:
  /// **'Возврат №:'**
  String get receiptLabelRefundNo;

  /// No description provided for @receiptLabelReason.
  ///
  /// In ru, this message translates to:
  /// **'Причина:'**
  String get receiptLabelReason;

  /// No description provided for @receiptLabelRefundTotal.
  ///
  /// In ru, this message translates to:
  /// **'К ВОЗВРАТУ:'**
  String get receiptLabelRefundTotal;

  /// No description provided for @receiptLabelZReport.
  ///
  /// In ru, this message translates to:
  /// **'Z-ОТЧЁТ'**
  String get receiptLabelZReport;

  /// No description provided for @receiptLabelShiftClosing.
  ///
  /// In ru, this message translates to:
  /// **'ЗАКРЫТИЕ СМЕНЫ'**
  String get receiptLabelShiftClosing;

  /// No description provided for @receiptLabelShiftNo.
  ///
  /// In ru, this message translates to:
  /// **'Смена №:'**
  String get receiptLabelShiftNo;

  /// No description provided for @receiptLabelShiftOpenTime.
  ///
  /// In ru, this message translates to:
  /// **'Открыта:'**
  String get receiptLabelShiftOpenTime;

  /// No description provided for @receiptLabelShiftCloseTime.
  ///
  /// In ru, this message translates to:
  /// **'Закрыта:'**
  String get receiptLabelShiftCloseTime;

  /// No description provided for @receiptLabelSales.
  ///
  /// In ru, this message translates to:
  /// **'ПРОДАЖИ'**
  String get receiptLabelSales;

  /// No description provided for @receiptLabelQuantity.
  ///
  /// In ru, this message translates to:
  /// **'Количество:'**
  String get receiptLabelQuantity;

  /// No description provided for @receiptLabelCashSales.
  ///
  /// In ru, this message translates to:
  /// **'Наличные:'**
  String get receiptLabelCashSales;

  /// No description provided for @receiptLabelCardSales.
  ///
  /// In ru, this message translates to:
  /// **'Карта:'**
  String get receiptLabelCardSales;

  /// No description provided for @receiptLabelSalesTotal.
  ///
  /// In ru, this message translates to:
  /// **'Итого:'**
  String get receiptLabelSalesTotal;

  /// No description provided for @receiptLabelRefunds.
  ///
  /// In ru, this message translates to:
  /// **'ВОЗВРАТЫ'**
  String get receiptLabelRefunds;

  /// No description provided for @receiptLabelRefundQty.
  ///
  /// In ru, this message translates to:
  /// **'Количество:'**
  String get receiptLabelRefundQty;

  /// No description provided for @receiptLabelRefundAmount.
  ///
  /// In ru, this message translates to:
  /// **'Сумма:'**
  String get receiptLabelRefundAmount;

  /// No description provided for @receiptLabelCashOperations.
  ///
  /// In ru, this message translates to:
  /// **'КАССОВЫЕ ОПЕРАЦИИ'**
  String get receiptLabelCashOperations;

  /// No description provided for @receiptLabelInvestments.
  ///
  /// In ru, this message translates to:
  /// **'Внесения:'**
  String get receiptLabelInvestments;

  /// No description provided for @receiptLabelExpenses.
  ///
  /// In ru, this message translates to:
  /// **'Выплаты:'**
  String get receiptLabelExpenses;

  /// No description provided for @receiptLabelRevenue.
  ///
  /// In ru, this message translates to:
  /// **'ВЫРУЧКА:'**
  String get receiptLabelRevenue;

  /// No description provided for @receiptLabelCashInDrawer.
  ///
  /// In ru, this message translates to:
  /// **'В КАССЕ:'**
  String get receiptLabelCashInDrawer;

  /// No description provided for @receiptLabelXReport.
  ///
  /// In ru, this message translates to:
  /// **'X-ОТЧЁТ'**
  String get receiptLabelXReport;

  /// No description provided for @receiptLabelType.
  ///
  /// In ru, this message translates to:
  /// **'Тип:'**
  String get receiptLabelType;

  /// No description provided for @receiptLabelDescription.
  ///
  /// In ru, this message translates to:
  /// **'Описание:'**
  String get receiptLabelDescription;

  /// No description provided for @receiptLabelDebtPayment.
  ///
  /// In ru, this message translates to:
  /// **'ПОГАШЕНИЕ ДОЛГА'**
  String get receiptLabelDebtPayment;

  /// No description provided for @receiptLabelPreviousDebt.
  ///
  /// In ru, this message translates to:
  /// **'Долг был:'**
  String get receiptLabelPreviousDebt;

  /// No description provided for @receiptLabelPaidAmount.
  ///
  /// In ru, this message translates to:
  /// **'ОПЛАЧЕНО:'**
  String get receiptLabelPaidAmount;

  /// No description provided for @receiptLabelRemainingDebt.
  ///
  /// In ru, this message translates to:
  /// **'Остаток:'**
  String get receiptLabelRemainingDebt;

  /// No description provided for @receiptLabelTestPrint.
  ///
  /// In ru, this message translates to:
  /// **'TEST PRINT'**
  String get receiptLabelTestPrint;

  /// No description provided for @receiptLabelThankYou.
  ///
  /// In ru, this message translates to:
  /// **'Спасибо за покупку!'**
  String get receiptLabelThankYou;

  /// No description provided for @receiptLabelSaleReceipt.
  ///
  /// In ru, this message translates to:
  /// **'КАССОВЫЙ ЧЕК'**
  String get receiptLabelSaleReceipt;

  /// No description provided for @receiptLabelOfflineHeader.
  ///
  /// In ru, this message translates to:
  /// **'*** ОФФЛАЙН РЕЖИМ ***'**
  String get receiptLabelOfflineHeader;

  /// No description provided for @receiptLabelVatCertificateTitle.
  ///
  /// In ru, this message translates to:
  /// **'Свидетельство НДС:'**
  String get receiptLabelVatCertificateTitle;

  /// No description provided for @fiscalErrorBin12Digits.
  ///
  /// In ru, this message translates to:
  /// **'БИН должен содержать 12 цифр'**
  String get fiscalErrorBin12Digits;

  /// No description provided for @fiscalErrorBinDigitsOnly.
  ///
  /// In ru, this message translates to:
  /// **'БИН должен содержать только цифры'**
  String get fiscalErrorBinDigitsOnly;

  /// No description provided for @fiscalErrorFiscalNoRequired.
  ///
  /// In ru, this message translates to:
  /// **'Фискальный номер обязателен'**
  String get fiscalErrorFiscalNoRequired;

  /// No description provided for @fiscalErrorRnkRequired.
  ///
  /// In ru, this message translates to:
  /// **'РНК обязателен'**
  String get fiscalErrorRnkRequired;

  /// No description provided for @fiscalErrorZnkRequired.
  ///
  /// In ru, this message translates to:
  /// **'ЗНК обязателен'**
  String get fiscalErrorZnkRequired;

  /// No description provided for @fiscalErrorVatSerialRequired.
  ///
  /// In ru, this message translates to:
  /// **'Серия свидетельства НДС обязательна'**
  String get fiscalErrorVatSerialRequired;

  /// No description provided for @fiscalErrorVatNumberRequired.
  ///
  /// In ru, this message translates to:
  /// **'Номер свидетельства НДС обязателен'**
  String get fiscalErrorVatNumberRequired;

  /// No description provided for @telegramTabPhone.
  ///
  /// In ru, this message translates to:
  /// **'По телефону'**
  String get telegramTabPhone;

  /// No description provided for @telegramTabQr.
  ///
  /// In ru, this message translates to:
  /// **'QR-код'**
  String get telegramTabQr;

  /// No description provided for @telegramQrAuthTitle.
  ///
  /// In ru, this message translates to:
  /// **'Вход через QR-код'**
  String get telegramQrAuthTitle;

  /// No description provided for @telegramQrAuthDescription.
  ///
  /// In ru, this message translates to:
  /// **'Отсканируйте QR-код в приложении Telegram на телефоне'**
  String get telegramQrAuthDescription;

  /// No description provided for @telegramQrTapToGenerate.
  ///
  /// In ru, this message translates to:
  /// **'Нажмите для генерации\nQR-кода'**
  String get telegramQrTapToGenerate;

  /// No description provided for @telegramQrHowToScan.
  ///
  /// In ru, this message translates to:
  /// **'Как отсканировать:'**
  String get telegramQrHowToScan;

  /// No description provided for @telegramQrStep1.
  ///
  /// In ru, this message translates to:
  /// **'Откройте Telegram на телефоне'**
  String get telegramQrStep1;

  /// No description provided for @telegramQrStep2.
  ///
  /// In ru, this message translates to:
  /// **'Перейдите в Настройки → Устройства'**
  String get telegramQrStep2;

  /// No description provided for @telegramQrStep3.
  ///
  /// In ru, this message translates to:
  /// **'Нажмите \"Подключить устройство\"'**
  String get telegramQrStep3;

  /// No description provided for @telegramQrStep4.
  ///
  /// In ru, this message translates to:
  /// **'Отсканируйте QR-код'**
  String get telegramQrStep4;

  /// No description provided for @telegramEnterCode.
  ///
  /// In ru, this message translates to:
  /// **'Введите код'**
  String get telegramEnterCode;

  /// No description provided for @telegramCodeSentTo.
  ///
  /// In ru, this message translates to:
  /// **'Код был отправлен в Telegram на номер\n{phone}'**
  String telegramCodeSentTo(String phone);

  /// No description provided for @telegramCodeLabel.
  ///
  /// In ru, this message translates to:
  /// **'Код подтверждения'**
  String get telegramCodeLabel;

  /// No description provided for @telegramPasswordDescription.
  ///
  /// In ru, this message translates to:
  /// **'Введите пароль от вашего аккаунта Telegram'**
  String get telegramPasswordDescription;

  /// No description provided for @telegramPasswordHint.
  ///
  /// In ru, this message translates to:
  /// **'Подсказка: {hint}'**
  String telegramPasswordHint(String hint);

  /// No description provided for @telegramPasswordLabel.
  ///
  /// In ru, this message translates to:
  /// **'Пароль'**
  String get telegramPasswordLabel;

  /// No description provided for @telegramRegistrationDescription.
  ///
  /// In ru, this message translates to:
  /// **'Аккаунт с этим номером не найден.\nСоздайте новый аккаунт Telegram.'**
  String get telegramRegistrationDescription;

  /// No description provided for @telegramFirstNameLabel.
  ///
  /// In ru, this message translates to:
  /// **'Имя'**
  String get telegramFirstNameLabel;

  /// No description provided for @telegramLastNameLabel.
  ///
  /// In ru, this message translates to:
  /// **'Фамилия (необязательно)'**
  String get telegramLastNameLabel;

  /// No description provided for @telegramLoadingOrgData.
  ///
  /// In ru, this message translates to:
  /// **'Загрузка данных организации...'**
  String get telegramLoadingOrgData;

  /// No description provided for @telegramSearchingExistingChannels.
  ///
  /// In ru, this message translates to:
  /// **'Поиск существующих каналов...'**
  String get telegramSearchingExistingChannels;

  /// No description provided for @telegramFoundChannels.
  ///
  /// In ru, this message translates to:
  /// **'Найдены каналы организации.\nЗагрузка конфигурации...'**
  String get telegramFoundChannels;

  /// No description provided for @telegramCheckingChannels.
  ///
  /// In ru, this message translates to:
  /// **'Проверяем наличие каналов...'**
  String get telegramCheckingChannels;

  /// No description provided for @telegramOrgDataNotLoaded.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить данные.\nВведите информацию о вашей организации.'**
  String get telegramOrgDataNotLoaded;

  /// No description provided for @telegramOrgDataFirstRun.
  ///
  /// In ru, this message translates to:
  /// **'Первый запуск TelePOS.\nВведите информацию о вашей организации.'**
  String get telegramOrgDataFirstRun;

  /// No description provided for @telegramStoreNameLabel.
  ///
  /// In ru, this message translates to:
  /// **'Название магазина *'**
  String get telegramStoreNameLabel;

  /// No description provided for @telegramStoreNameHint.
  ///
  /// In ru, this message translates to:
  /// **'Мой магазин'**
  String get telegramStoreNameHint;

  /// No description provided for @telegramBinLabel.
  ///
  /// In ru, this message translates to:
  /// **'БИН/ИИН организации *'**
  String get telegramBinLabel;

  /// No description provided for @telegramAddressLabel.
  ///
  /// In ru, this message translates to:
  /// **'Адрес (необязательно)'**
  String get telegramAddressLabel;

  /// No description provided for @telegramAddressHint.
  ///
  /// In ru, this message translates to:
  /// **'г. Алматы, ул. Примерная, 123'**
  String get telegramAddressHint;

  /// No description provided for @telegramPosIdLabel.
  ///
  /// In ru, this message translates to:
  /// **'ID кассы'**
  String get telegramPosIdLabel;

  /// No description provided for @telegramOwnerNameLabel.
  ///
  /// In ru, this message translates to:
  /// **'Имя владельца (необязательно)'**
  String get telegramOwnerNameLabel;

  /// No description provided for @telegramImportantNote.
  ///
  /// In ru, this message translates to:
  /// **'Важно'**
  String get telegramImportantNote;

  /// No description provided for @telegramOrgDataNote.
  ///
  /// In ru, this message translates to:
  /// **'Эти данные будут использоваться для создания системных каналов и синхронизации между кассами. На других устройствах данные загрузятся автоматически.'**
  String get telegramOrgDataNote;

  /// No description provided for @telegramCreatingChannels.
  ///
  /// In ru, this message translates to:
  /// **'Создание системных каналов...'**
  String get telegramCreatingChannels;

  /// No description provided for @telegramSettingUpEncryption.
  ///
  /// In ru, this message translates to:
  /// **'Настройка шифрования...'**
  String get telegramSettingUpEncryption;

  /// No description provided for @telegramSettingUp.
  ///
  /// In ru, this message translates to:
  /// **'Настройка...'**
  String get telegramSettingUp;

  /// No description provided for @telegramPleaseWait.
  ///
  /// In ru, this message translates to:
  /// **'Пожалуйста, подождите.\nЭто может занять некоторое время.'**
  String get telegramPleaseWait;

  /// No description provided for @telegramSetupDone.
  ///
  /// In ru, this message translates to:
  /// **'Настройка завершена!'**
  String get telegramSetupDone;

  /// No description provided for @telegramSetupDoneMessage.
  ///
  /// In ru, this message translates to:
  /// **'Telegram успешно настроен.\nСистемные каналы созданы.'**
  String get telegramSetupDoneMessage;

  /// No description provided for @telegramTermsNotice.
  ///
  /// In ru, this message translates to:
  /// **'Нажимая \"Получить код\", вы соглашаетесь с условиями использования Telegram'**
  String get telegramTermsNotice;

  /// No description provided for @telegramActionsSection.
  ///
  /// In ru, this message translates to:
  /// **'Действия'**
  String get telegramActionsSection;

  /// No description provided for @chatNotConfigured.
  ///
  /// In ru, this message translates to:
  /// **'Чат не настроен'**
  String get chatNotConfigured;

  /// No description provided for @chatCanDeleteOwnOnly.
  ///
  /// In ru, this message translates to:
  /// **'Можно удалять только свои сообщения'**
  String get chatCanDeleteOwnOnly;

  /// No description provided for @chatMessageDeleted.
  ///
  /// In ru, this message translates to:
  /// **'Сообщение удалено'**
  String get chatMessageDeleted;

  /// No description provided for @chatDeleteFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось удалить сообщение'**
  String get chatDeleteFailed;

  /// No description provided for @chatTelegramNotLinked.
  ///
  /// In ru, this message translates to:
  /// **'Telegram не привязан'**
  String get chatTelegramNotLinked;

  /// No description provided for @chatLinkInstructions.
  ///
  /// In ru, this message translates to:
  /// **'Введите ваш Telegram User ID для идентификации в чате сотрудников.'**
  String get chatLinkInstructions;

  /// No description provided for @chatLinkHowTo.
  ///
  /// In ru, this message translates to:
  /// **'Как узнать ID:\n1. Откройте @userinfobot в Telegram\n2. Нажмите /start\n3. Скопируйте число из поля \"Id\"'**
  String get chatLinkHowTo;

  /// No description provided for @chatLinkFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось привязать. Возможно, этот ID уже используется.'**
  String get chatLinkFailed;

  /// No description provided for @chatPhotoSent.
  ///
  /// In ru, this message translates to:
  /// **'Фото отправлено'**
  String get chatPhotoSent;

  /// No description provided for @chatPhotoFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось отправить фото'**
  String get chatPhotoFailed;

  /// No description provided for @chatPhotoError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка при выборе фото'**
  String get chatPhotoError;

  /// No description provided for @chatPhotoUnavailableWeb.
  ///
  /// In ru, this message translates to:
  /// **'Отправка фото недоступна в веб-версии'**
  String get chatPhotoUnavailableWeb;

  /// No description provided for @chatDocSent.
  ///
  /// In ru, this message translates to:
  /// **'Документ отправлен'**
  String get chatDocSent;

  /// No description provided for @chatDocFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось отправить документ'**
  String get chatDocFailed;

  /// No description provided for @chatDocError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка при выборе документа'**
  String get chatDocError;

  /// No description provided for @chatDocUnavailableWeb.
  ///
  /// In ru, this message translates to:
  /// **'Отправка документов недоступна в веб-версии'**
  String get chatDocUnavailableWeb;

  /// No description provided for @chatDocPathError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось получить путь к файлу'**
  String get chatDocPathError;

  /// No description provided for @chatDocTooLarge.
  ///
  /// In ru, this message translates to:
  /// **'Файл слишком большой (макс. 50 МБ)'**
  String get chatDocTooLarge;

  /// No description provided for @chatLocationSent.
  ///
  /// In ru, this message translates to:
  /// **'Местоположение отправлено'**
  String get chatLocationSent;

  /// No description provided for @chatLocationFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось отправить местоположение'**
  String get chatLocationFailed;

  /// No description provided for @chatLocationError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка получения местоположения'**
  String get chatLocationError;

  /// No description provided for @chatLocationUnavailableWeb.
  ///
  /// In ru, this message translates to:
  /// **'Геолокация недоступна в веб-версии'**
  String get chatLocationUnavailableWeb;

  /// No description provided for @chatLocationDenied.
  ///
  /// In ru, this message translates to:
  /// **'Доступ к геолокации запрещён'**
  String get chatLocationDenied;

  /// No description provided for @chatLocationDeniedForever.
  ///
  /// In ru, this message translates to:
  /// **'Доступ к геолокации запрещён навсегда. Измените в настройках.'**
  String get chatLocationDeniedForever;

  /// No description provided for @chatLocationServiceDisabled.
  ///
  /// In ru, this message translates to:
  /// **'Включите геолокацию на устройстве'**
  String get chatLocationServiceDisabled;

  /// No description provided for @syncToUpload.
  ///
  /// In ru, this message translates to:
  /// **'К выгрузке'**
  String get syncToUpload;

  /// No description provided for @syncToDownload.
  ///
  /// In ru, this message translates to:
  /// **'К загрузке'**
  String get syncToDownload;

  /// No description provided for @syncDataTypeCol.
  ///
  /// In ru, this message translates to:
  /// **'Тип данных'**
  String get syncDataTypeCol;

  /// No description provided for @syncDirectionCol.
  ///
  /// In ru, this message translates to:
  /// **'Направление'**
  String get syncDirectionCol;

  /// No description provided for @syncPendingCol.
  ///
  /// In ru, this message translates to:
  /// **'Ожидает'**
  String get syncPendingCol;

  /// No description provided for @syncStatusCol.
  ///
  /// In ru, this message translates to:
  /// **'Статус'**
  String get syncStatusCol;

  /// No description provided for @syncProgressCol.
  ///
  /// In ru, this message translates to:
  /// **'Прогресс'**
  String get syncProgressCol;

  /// No description provided for @syncUpload.
  ///
  /// In ru, this message translates to:
  /// **'Выгрузка'**
  String get syncUpload;

  /// No description provided for @syncDownload.
  ///
  /// In ru, this message translates to:
  /// **'Загрузка'**
  String get syncDownload;

  /// No description provided for @syncPendingCount.
  ///
  /// In ru, this message translates to:
  /// **'Ожидает: {count}'**
  String syncPendingCount(int count);

  /// No description provided for @syncInfoTelegram.
  ///
  /// In ru, this message translates to:
  /// **'Данные синхронизируются между кассами через Telegram. Пользователи общие для всех касс.'**
  String get syncInfoTelegram;

  /// No description provided for @syncAutoEnabled.
  ///
  /// In ru, this message translates to:
  /// **'Данные синхронизируются автоматически'**
  String get syncAutoEnabled;

  /// No description provided for @syncManualOnly.
  ///
  /// In ru, this message translates to:
  /// **'Синхронизация только вручную'**
  String get syncManualOnly;

  /// No description provided for @syncMinutes.
  ///
  /// In ru, this message translates to:
  /// **'{count} мин'**
  String syncMinutes(int count);

  /// No description provided for @agentBinIin.
  ///
  /// In ru, this message translates to:
  /// **'БИН/ИИН'**
  String get agentBinIin;

  /// No description provided for @agentLastOperation.
  ///
  /// In ru, this message translates to:
  /// **'Последняя операция'**
  String get agentLastOperation;

  /// No description provided for @agentNoAdditionalInfo.
  ///
  /// In ru, this message translates to:
  /// **'Нет дополнительной информации'**
  String get agentNoAdditionalInfo;

  /// No description provided for @agentNoDebt.
  ///
  /// In ru, this message translates to:
  /// **'Нет задолженности'**
  String get agentNoDebt;

  /// No description provided for @agentDeletedWithName.
  ///
  /// In ru, this message translates to:
  /// **'Клиент \"{name}\" удалён'**
  String agentDeletedWithName(String name);

  /// No description provided for @agentDeleteError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка удаления: {error}'**
  String agentDeleteError(String error);

  /// No description provided for @agentNewCustomer.
  ///
  /// In ru, this message translates to:
  /// **'Новый клиент'**
  String get agentNewCustomer;

  /// No description provided for @agentTypeCustomer.
  ///
  /// In ru, this message translates to:
  /// **'Клиент'**
  String get agentTypeCustomer;

  /// No description provided for @agentTypeSupplier.
  ///
  /// In ru, this message translates to:
  /// **'Поставщик'**
  String get agentTypeSupplier;

  /// No description provided for @agentNameHint.
  ///
  /// In ru, this message translates to:
  /// **'Введите имя'**
  String get agentNameHint;

  /// No description provided for @agentBinHint.
  ///
  /// In ru, this message translates to:
  /// **'12 цифр'**
  String get agentBinHint;

  /// No description provided for @agentCustomerFound.
  ///
  /// In ru, this message translates to:
  /// **'Клиент найден'**
  String get agentCustomerFound;

  /// No description provided for @agentDeletedPhoneMsg.
  ///
  /// In ru, this message translates to:
  /// **'Клиент с таким телефоном был удалён'**
  String get agentDeletedPhoneMsg;

  /// No description provided for @agentRestoreQuestion.
  ///
  /// In ru, this message translates to:
  /// **'Хотите восстановить?'**
  String get agentRestoreQuestion;

  /// No description provided for @agentRestore.
  ///
  /// In ru, this message translates to:
  /// **'Восстановить'**
  String get agentRestore;

  /// No description provided for @kaspiTerminal.
  ///
  /// In ru, this message translates to:
  /// **'Kaspi POS Терминал'**
  String get kaspiTerminal;

  /// No description provided for @kaspiIpAddress.
  ///
  /// In ru, this message translates to:
  /// **'IP-адрес терминала'**
  String get kaspiIpAddress;

  /// No description provided for @kaspiInvalidIp.
  ///
  /// In ru, this message translates to:
  /// **'Неверный формат IP-адреса'**
  String get kaspiInvalidIp;

  /// No description provided for @kaspiPort.
  ///
  /// In ru, this message translates to:
  /// **'Порт'**
  String get kaspiPort;

  /// No description provided for @kaspiTesting.
  ///
  /// In ru, this message translates to:
  /// **'Проверка...'**
  String get kaspiTesting;

  /// No description provided for @kaspiTest.
  ///
  /// In ru, this message translates to:
  /// **'ТЕСТ'**
  String get kaspiTest;

  /// No description provided for @kaspiDisconnected.
  ///
  /// In ru, this message translates to:
  /// **'Не подключено'**
  String get kaspiDisconnected;

  /// No description provided for @kaspiConnecting.
  ///
  /// In ru, this message translates to:
  /// **'Подключение...'**
  String get kaspiConnecting;

  /// No description provided for @kaspiConnected.
  ///
  /// In ru, this message translates to:
  /// **'Соединение установлено'**
  String get kaspiConnected;

  /// No description provided for @kaspiNoConnection.
  ///
  /// In ru, this message translates to:
  /// **'Нет соединения'**
  String get kaspiNoConnection;

  /// No description provided for @kaspiTestPassed.
  ///
  /// In ru, this message translates to:
  /// **'Тест пройден'**
  String get kaspiTestPassed;

  /// No description provided for @kaspiTestFailed.
  ///
  /// In ru, this message translates to:
  /// **'Тест не пройден'**
  String get kaspiTestFailed;

  /// No description provided for @kaspiLatency.
  ///
  /// In ru, this message translates to:
  /// **'Задержка: {ms} мс'**
  String kaspiLatency(String ms);

  /// No description provided for @kaspiTerminalInfo.
  ///
  /// In ru, this message translates to:
  /// **'Терминал: {info}'**
  String kaspiTerminalInfo(String info);

  /// No description provided for @splashSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Система кассового обслуживания'**
  String get splashSubtitle;

  /// No description provided for @splashInitializing.
  ///
  /// In ru, this message translates to:
  /// **'Инициализация...'**
  String get splashInitializing;

  /// No description provided for @splashLoadingOrg.
  ///
  /// In ru, this message translates to:
  /// **'Загрузка данных организации...'**
  String get splashLoadingOrg;

  /// No description provided for @splashEnterPosKey.
  ///
  /// In ru, this message translates to:
  /// **'Введите ключ POS'**
  String get splashEnterPosKey;

  /// No description provided for @splashEnterPosKeyMessage.
  ///
  /// In ru, this message translates to:
  /// **'Для активации кассы введите ключ, полученный от администратора.'**
  String get splashEnterPosKeyMessage;

  /// No description provided for @splashPosKeyHint.
  ///
  /// In ru, this message translates to:
  /// **'XXXX-XXXX-XXXX-XXXX'**
  String get splashPosKeyHint;

  /// No description provided for @splashKeyEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Ключ не может быть пустым'**
  String get splashKeyEmpty;

  /// No description provided for @splashKeyTooShort.
  ///
  /// In ru, this message translates to:
  /// **'Ключ слишком короткий'**
  String get splashKeyTooShort;

  /// No description provided for @splashKeyNotEntered.
  ///
  /// In ru, this message translates to:
  /// **'Ключ не введён'**
  String get splashKeyNotEntered;

  /// No description provided for @splashKeyRequiredMessage.
  ///
  /// In ru, this message translates to:
  /// **'Без ключа POS работа невозможна. Приложение будет закрыто.'**
  String get splashKeyRequiredMessage;

  /// No description provided for @splashDataCorrupted.
  ///
  /// In ru, this message translates to:
  /// **'Данные повреждены'**
  String get splashDataCorrupted;

  /// No description provided for @splashDataCorruptedMessage.
  ///
  /// In ru, this message translates to:
  /// **'Обязательные данные приложения отсутствуют или повреждены.\n\nВыберите действие:'**
  String get splashDataCorruptedMessage;

  /// No description provided for @splashReconfigure.
  ///
  /// In ru, this message translates to:
  /// **'Настроить заново'**
  String get splashReconfigure;

  /// No description provided for @splashExit.
  ///
  /// In ru, this message translates to:
  /// **'Выйти'**
  String get splashExit;

  /// No description provided for @splashDatabaseError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка базы данных'**
  String get splashDatabaseError;

  /// No description provided for @splashDatabaseErrorMessage.
  ///
  /// In ru, this message translates to:
  /// **'База данных повреждена или недоступна.\n\nВы можете попробовать восстановить из резервной копии или настроить кассу заново.'**
  String get splashDatabaseErrorMessage;

  /// No description provided for @splashRestoreFromBackup.
  ///
  /// In ru, this message translates to:
  /// **'Восстановить из бэкапа'**
  String get splashRestoreFromBackup;

  /// No description provided for @splashSyncSuspended.
  ///
  /// In ru, this message translates to:
  /// **'Синхронизация приостановлена'**
  String get splashSyncSuspended;

  /// No description provided for @splashSyncSuspendedMessage.
  ///
  /// In ru, this message translates to:
  /// **'Синхронизация данных временно приостановлена.\n\nКасса работает в автономном режиме. Данные будут синхронизированы при восстановлении связи.'**
  String get splashSyncSuspendedMessage;

  /// No description provided for @splashAuthError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка авторизации\n\nТокен доступа недействителен или истёк.\nОбратитесь к администратору для получения нового ключа.'**
  String get splashAuthError;

  /// No description provided for @splashSupportEnded.
  ///
  /// In ru, this message translates to:
  /// **'Версия не поддерживается\n\nЭта версия приложения больше не поддерживается.\nПожалуйста, обновите приложение до последней версии.'**
  String get splashSupportEnded;

  /// No description provided for @generalSettingsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Настройки'**
  String get generalSettingsTitle;

  /// No description provided for @generalSettingsPosInfo.
  ///
  /// In ru, this message translates to:
  /// **'Информация о кассе'**
  String get generalSettingsPosInfo;

  /// No description provided for @generalSettingsCashBoxName.
  ///
  /// In ru, this message translates to:
  /// **'Название кассы'**
  String get generalSettingsCashBoxName;

  /// No description provided for @generalSettingsCompany.
  ///
  /// In ru, this message translates to:
  /// **'Компания'**
  String get generalSettingsCompany;

  /// No description provided for @generalSettingsIinBin.
  ///
  /// In ru, this message translates to:
  /// **'ИИН/БИН'**
  String get generalSettingsIinBin;

  /// No description provided for @generalSettingsPosId.
  ///
  /// In ru, this message translates to:
  /// **'ID POS'**
  String get generalSettingsPosId;

  /// No description provided for @generalSettingsStoreId.
  ///
  /// In ru, this message translates to:
  /// **'ID магазина'**
  String get generalSettingsStoreId;

  /// No description provided for @generalSettingsNotSpecified.
  ///
  /// In ru, this message translates to:
  /// **'Не указано'**
  String get generalSettingsNotSpecified;

  /// No description provided for @generalSettingsAppVersion.
  ///
  /// In ru, this message translates to:
  /// **'Версия приложения'**
  String get generalSettingsAppVersion;

  /// No description provided for @generalSettingsVersion.
  ///
  /// In ru, this message translates to:
  /// **'Версия'**
  String get generalSettingsVersion;

  /// No description provided for @generalSettingsPlatform.
  ///
  /// In ru, this message translates to:
  /// **'Платформа'**
  String get generalSettingsPlatform;

  /// No description provided for @generalSettingsLanguage.
  ///
  /// In ru, this message translates to:
  /// **'Язык интерфейса'**
  String get generalSettingsLanguage;

  /// No description provided for @generalSettingsTheme.
  ///
  /// In ru, this message translates to:
  /// **'Оформление'**
  String get generalSettingsTheme;

  /// No description provided for @generalSettingsThemeDesc.
  ///
  /// In ru, this message translates to:
  /// **'Светлая, тёмная или как в системе'**
  String get generalSettingsThemeDesc;

  /// No description provided for @generalSettingsThemeLight.
  ///
  /// In ru, this message translates to:
  /// **'Светлая'**
  String get generalSettingsThemeLight;

  /// No description provided for @generalSettingsThemeDark.
  ///
  /// In ru, this message translates to:
  /// **'Тёмная'**
  String get generalSettingsThemeDark;

  /// No description provided for @generalSettingsThemeSystem.
  ///
  /// In ru, this message translates to:
  /// **'Как в системе'**
  String get generalSettingsThemeSystem;

  /// No description provided for @generalSettingsLanguageChanged.
  ///
  /// In ru, this message translates to:
  /// **'Язык изменён на {language}'**
  String generalSettingsLanguageChanged(String language);

  /// No description provided for @generalSettingsCurrency.
  ///
  /// In ru, this message translates to:
  /// **'Валюта'**
  String get generalSettingsCurrency;

  /// No description provided for @generalSettingsCurrencySymbol.
  ///
  /// In ru, this message translates to:
  /// **'Символ'**
  String get generalSettingsCurrencySymbol;

  /// No description provided for @generalSettingsCurrencyCode.
  ///
  /// In ru, this message translates to:
  /// **'Код'**
  String get generalSettingsCurrencyCode;

  /// No description provided for @generalSettingsCountry.
  ///
  /// In ru, this message translates to:
  /// **'Страна'**
  String get generalSettingsCountry;

  /// No description provided for @generalSettingsAdditional.
  ///
  /// In ru, this message translates to:
  /// **'Дополнительные настройки'**
  String get generalSettingsAdditional;

  /// No description provided for @generalSettingsTransport.
  ///
  /// In ru, this message translates to:
  /// **'Транспорт'**
  String get generalSettingsTransport;

  /// No description provided for @generalSettingsTransportSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Настройки синхронизации данных'**
  String get generalSettingsTransportSubtitle;

  /// No description provided for @generalSettingsPrinter.
  ///
  /// In ru, this message translates to:
  /// **'Принтер'**
  String get generalSettingsPrinter;

  /// No description provided for @generalSettingsPrinterSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Настройки печати чеков'**
  String get generalSettingsPrinterSubtitle;

  /// No description provided for @generalSettingsPermissions.
  ///
  /// In ru, this message translates to:
  /// **'Права доступа'**
  String get generalSettingsPermissions;

  /// No description provided for @generalSettingsPermissionsSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Разрешения для кассиров'**
  String get generalSettingsPermissionsSubtitle;

  /// No description provided for @generalSettingsFiscal.
  ///
  /// In ru, this message translates to:
  /// **'Фискализация'**
  String get generalSettingsFiscal;

  /// No description provided for @generalSettingsFiscalSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'WebKassa, ОФД, НДС'**
  String get generalSettingsFiscalSubtitle;

  /// No description provided for @generalSettingsRestaurant.
  ///
  /// In ru, this message translates to:
  /// **'Режим работы'**
  String get generalSettingsRestaurant;

  /// No description provided for @generalSettingsRestaurantSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Розница, ресторан, сервис'**
  String get generalSettingsRestaurantSubtitle;

  /// No description provided for @generalSettingsTelegram.
  ///
  /// In ru, this message translates to:
  /// **'Telegram'**
  String get generalSettingsTelegram;

  /// No description provided for @generalSettingsTelegramSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Каналы связи и боты'**
  String get generalSettingsTelegramSubtitle;

  /// No description provided for @generalSettingsPosInfoDesc.
  ///
  /// In ru, this message translates to:
  /// **'Название кассы, компания, ID'**
  String get generalSettingsPosInfoDesc;

  /// No description provided for @generalSettingsVersionDesc.
  ///
  /// In ru, this message translates to:
  /// **'Текущая версия и платформа'**
  String get generalSettingsVersionDesc;

  /// No description provided for @generalSettingsLanguageDesc.
  ///
  /// In ru, this message translates to:
  /// **'Выбор языка интерфейса'**
  String get generalSettingsLanguageDesc;

  /// No description provided for @generalSettingsCurrencyDesc.
  ///
  /// In ru, this message translates to:
  /// **'Валюта и страна'**
  String get generalSettingsCurrencyDesc;

  /// No description provided for @generalSettingsUpdate.
  ///
  /// In ru, this message translates to:
  /// **'Обновление'**
  String get generalSettingsUpdate;

  /// No description provided for @generalSettingsUpdateSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Проверка и установка обновлений'**
  String get generalSettingsUpdateSubtitle;

  /// No description provided for @generalSettingsAppUpdate.
  ///
  /// In ru, this message translates to:
  /// **'Обновление приложения'**
  String get generalSettingsAppUpdate;

  /// No description provided for @generalSettingsAppUpdateSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Обновление кассы (не путать с обновлением ОС)'**
  String get generalSettingsAppUpdateSubtitle;

  /// No description provided for @generalSettingsUpdateDesc.
  ///
  /// In ru, this message translates to:
  /// **'Текущая версия и обновления'**
  String get generalSettingsUpdateDesc;

  /// No description provided for @settingsUpdateTitle.
  ///
  /// In ru, this message translates to:
  /// **'Обновление приложения'**
  String get settingsUpdateTitle;

  /// No description provided for @settingsUpdateCurrentVersion.
  ///
  /// In ru, this message translates to:
  /// **'Текущая версия'**
  String get settingsUpdateCurrentVersion;

  /// No description provided for @settingsUpdateCheckBtn.
  ///
  /// In ru, this message translates to:
  /// **'Проверить обновления'**
  String get settingsUpdateCheckBtn;

  /// No description provided for @settingsUpdateChecking.
  ///
  /// In ru, this message translates to:
  /// **'Проверка обновлений...'**
  String get settingsUpdateChecking;

  /// No description provided for @settingsUpdateUpToDate.
  ///
  /// In ru, this message translates to:
  /// **'Установлена последняя версия'**
  String get settingsUpdateUpToDate;

  /// No description provided for @settingsUpdateAvailable.
  ///
  /// In ru, this message translates to:
  /// **'Доступна версия {version}'**
  String settingsUpdateAvailable(String version);

  /// No description provided for @settingsUpdateDownloadBtn.
  ///
  /// In ru, this message translates to:
  /// **'Скачать обновление'**
  String get settingsUpdateDownloadBtn;

  /// No description provided for @settingsUpdateDownloading.
  ///
  /// In ru, this message translates to:
  /// **'Загрузка... {percent}%'**
  String settingsUpdateDownloading(String percent);

  /// No description provided for @settingsUpdateInstallBtn.
  ///
  /// In ru, this message translates to:
  /// **'Установить обновление'**
  String get settingsUpdateInstallBtn;

  /// No description provided for @settingsUpdateInstalling.
  ///
  /// In ru, this message translates to:
  /// **'Установка...'**
  String get settingsUpdateInstalling;

  /// No description provided for @settingsUpdateFailed.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка обновления'**
  String get settingsUpdateFailed;

  /// No description provided for @settingsUpdateAutoEnabled.
  ///
  /// In ru, this message translates to:
  /// **'Автоматическая проверка каждые 3 часа'**
  String get settingsUpdateAutoEnabled;

  /// No description provided for @settingsUpdateCloseShift.
  ///
  /// In ru, this message translates to:
  /// **'Закройте смену перед обновлением'**
  String get settingsUpdateCloseShift;

  /// No description provided for @settingsUpdateReleaseNotes.
  ///
  /// In ru, this message translates to:
  /// **'Что нового'**
  String get settingsUpdateReleaseNotes;

  /// No description provided for @countryKazakhstan.
  ///
  /// In ru, this message translates to:
  /// **'Казахстан'**
  String get countryKazakhstan;

  /// No description provided for @countryRussia.
  ///
  /// In ru, this message translates to:
  /// **'Россия'**
  String get countryRussia;

  /// No description provided for @countryKyrgyzstan.
  ///
  /// In ru, this message translates to:
  /// **'Кыргызстан'**
  String get countryKyrgyzstan;

  /// No description provided for @countryUzbekistan.
  ///
  /// In ru, this message translates to:
  /// **'Узбекистан'**
  String get countryUzbekistan;

  /// No description provided for @countryUSA.
  ///
  /// In ru, this message translates to:
  /// **'США'**
  String get countryUSA;

  /// No description provided for @countryTurkmenistan.
  ///
  /// In ru, this message translates to:
  /// **'Туркменистан'**
  String get countryTurkmenistan;

  /// No description provided for @permNavServiceQueue.
  ///
  /// In ru, this message translates to:
  /// **'Очередь заказов'**
  String get permNavServiceQueue;

  /// No description provided for @permNavServiceIntake.
  ///
  /// In ru, this message translates to:
  /// **'Приём заказов'**
  String get permNavServiceIntake;

  /// No description provided for @permSellWithDiscount.
  ///
  /// In ru, this message translates to:
  /// **'Продажа со скидкой'**
  String get permSellWithDiscount;

  /// No description provided for @permCashInOut.
  ///
  /// In ru, this message translates to:
  /// **'Внесение / изъятие'**
  String get permCashInOut;

  /// No description provided for @permRefundGoods.
  ///
  /// In ru, this message translates to:
  /// **'Возврат товара'**
  String get permRefundGoods;

  /// No description provided for @permRefundWithoutReceipt.
  ///
  /// In ru, this message translates to:
  /// **'Возврат без чека'**
  String get permRefundWithoutReceipt;

  /// No description provided for @permGroupNavigation.
  ///
  /// In ru, this message translates to:
  /// **'Навигация'**
  String get permGroupNavigation;

  /// No description provided for @permEditPrice.
  ///
  /// In ru, this message translates to:
  /// **'Редактирование цены'**
  String get permEditPrice;

  /// No description provided for @permSellInDebt.
  ///
  /// In ru, this message translates to:
  /// **'Продажа в долг'**
  String get permSellInDebt;

  /// No description provided for @permDiscounts.
  ///
  /// In ru, this message translates to:
  /// **'Скидки'**
  String get permDiscounts;

  /// No description provided for @permCashOperations.
  ///
  /// In ru, this message translates to:
  /// **'Кассовые операции'**
  String get permCashOperations;

  /// No description provided for @permSendToOfd.
  ///
  /// In ru, this message translates to:
  /// **'Отправка в ОФД'**
  String get permSendToOfd;

  /// No description provided for @permCancelPayment.
  ///
  /// In ru, this message translates to:
  /// **'Отмена платежа'**
  String get permCancelPayment;

  /// No description provided for @permDeferSale.
  ///
  /// In ru, this message translates to:
  /// **'Отложенная продажа'**
  String get permDeferSale;

  /// No description provided for @permShowHistory.
  ///
  /// In ru, this message translates to:
  /// **'Показать историю'**
  String get permShowHistory;

  /// No description provided for @printerSettingsSaved.
  ///
  /// In ru, this message translates to:
  /// **'Настройки сохранены'**
  String get printerSettingsSaved;

  /// No description provided for @printerSettingsSaveError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка сохранения: {error}'**
  String printerSettingsSaveError(String error);

  /// No description provided for @printerSettingsPrinting.
  ///
  /// In ru, this message translates to:
  /// **'Печать...'**
  String get printerSettingsPrinting;

  /// No description provided for @printerSettingsTestReceipt.
  ///
  /// In ru, this message translates to:
  /// **'ТЕСТОВЫЙ ЧЕК'**
  String get printerSettingsTestReceipt;

  /// No description provided for @printerSettingsWidth.
  ///
  /// In ru, this message translates to:
  /// **'Ширина:'**
  String get printerSettingsWidth;

  /// No description provided for @printerSettingsWidthValue.
  ///
  /// In ru, this message translates to:
  /// **'{width} символов'**
  String printerSettingsWidthValue(int width);

  /// No description provided for @printerSettingsType.
  ///
  /// In ru, this message translates to:
  /// **'Тип:'**
  String get printerSettingsType;

  /// No description provided for @printerSettingsAddress.
  ///
  /// In ru, this message translates to:
  /// **'Адрес:'**
  String get printerSettingsAddress;

  /// No description provided for @printerSettingsNotSpecifiedAddr.
  ///
  /// In ru, this message translates to:
  /// **'Не указан'**
  String get printerSettingsNotSpecifiedAddr;

  /// No description provided for @printerSettingsPrinterWorks.
  ///
  /// In ru, this message translates to:
  /// **'Принтер работает!'**
  String get printerSettingsPrinterWorks;

  /// No description provided for @printerSettingsPrintSuccess.
  ///
  /// In ru, this message translates to:
  /// **'Печать успешна'**
  String get printerSettingsPrintSuccess;

  /// No description provided for @printerSettingsPrintError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка печати'**
  String get printerSettingsPrintError;

  /// No description provided for @printerSettingsNotConnected.
  ///
  /// In ru, this message translates to:
  /// **'Не подключен'**
  String get printerSettingsNotConnected;

  /// No description provided for @printerSettingsChecking.
  ///
  /// In ru, this message translates to:
  /// **'Проверка...'**
  String get printerSettingsChecking;

  /// No description provided for @printerSettingsReady.
  ///
  /// In ru, this message translates to:
  /// **'Готов'**
  String get printerSettingsReady;

  /// No description provided for @printerSettingsNoPaper.
  ///
  /// In ru, this message translates to:
  /// **'Нет бумаги'**
  String get printerSettingsNoPaper;

  /// No description provided for @printerSettingsCoverOpen.
  ///
  /// In ru, this message translates to:
  /// **'Открыта крышка'**
  String get printerSettingsCoverOpen;

  /// No description provided for @printerSettingsSave.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить'**
  String get printerSettingsSave;

  /// No description provided for @printerSettingsConnectionType.
  ///
  /// In ru, this message translates to:
  /// **'Тип подключения'**
  String get printerSettingsConnectionType;

  /// No description provided for @printerSettingsPrinterAddress.
  ///
  /// In ru, this message translates to:
  /// **'Адрес принтера'**
  String get printerSettingsPrinterAddress;

  /// No description provided for @printerSettingsPaperWidth.
  ///
  /// In ru, this message translates to:
  /// **'Ширина бумаги'**
  String get printerSettingsPaperWidth;

  /// No description provided for @printerSettingsTesting.
  ///
  /// In ru, this message translates to:
  /// **'Тестирование'**
  String get printerSettingsTesting;

  /// No description provided for @printerSettingsStatus.
  ///
  /// In ru, this message translates to:
  /// **'Статус: {status}'**
  String printerSettingsStatus(String status);

  /// No description provided for @printerSettingsCheck.
  ///
  /// In ru, this message translates to:
  /// **'Проверить'**
  String get printerSettingsCheck;

  /// No description provided for @printerSettingsTestCheck.
  ///
  /// In ru, this message translates to:
  /// **'Тестовый чек'**
  String get printerSettingsTestCheck;

  /// No description provided for @printerSettingsPort.
  ///
  /// In ru, this message translates to:
  /// **'Порт'**
  String get printerSettingsPort;

  /// No description provided for @printerSettingsIpAddress.
  ///
  /// In ru, this message translates to:
  /// **'IP адрес принтера'**
  String get printerSettingsIpAddress;

  /// No description provided for @printerSettingsMacAddress.
  ///
  /// In ru, this message translates to:
  /// **'MAC адрес или имя'**
  String get printerSettingsMacAddress;

  /// No description provided for @printerSettingsPrinterName.
  ///
  /// In ru, this message translates to:
  /// **'Имя принтера'**
  String get printerSettingsPrinterName;

  /// No description provided for @printerSettingsComPort.
  ///
  /// In ru, this message translates to:
  /// **'COM порт'**
  String get printerSettingsComPort;

  /// No description provided for @printerSettingsSerialCom.
  ///
  /// In ru, this message translates to:
  /// **'Serial (COM)'**
  String get printerSettingsSerialCom;

  /// No description provided for @printerSettingsPaperWidth58.
  ///
  /// In ru, this message translates to:
  /// **'58mm (32 символа)'**
  String get printerSettingsPaperWidth58;

  /// No description provided for @printerSettingsPaperWidth80_42.
  ///
  /// In ru, this message translates to:
  /// **'80mm (42 символа)'**
  String get printerSettingsPaperWidth80_42;

  /// No description provided for @printerSettingsPaperWidth80_48.
  ///
  /// In ru, this message translates to:
  /// **'80mm (48 символов)'**
  String get printerSettingsPaperWidth80_48;

  /// No description provided for @fiscalSettingsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Фискализация'**
  String get fiscalSettingsTitle;

  /// No description provided for @fiscalSettingsSaved.
  ///
  /// In ru, this message translates to:
  /// **'Настройки сохранены'**
  String get fiscalSettingsSaved;

  /// No description provided for @fiscalSettingsSaveError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка сохранения: {error}'**
  String fiscalSettingsSaveError(String error);

  /// No description provided for @fiscalSettingsSave.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить'**
  String get fiscalSettingsSave;

  /// No description provided for @fiscalSettingsOperator.
  ///
  /// In ru, this message translates to:
  /// **'Фискальный оператор'**
  String get fiscalSettingsOperator;

  /// No description provided for @fiscalSettingsWebkassaSettings.
  ///
  /// In ru, this message translates to:
  /// **'Настройки WebKassa'**
  String get fiscalSettingsWebkassaSettings;

  /// No description provided for @fiscalSettingsTaxpayerInfo.
  ///
  /// In ru, this message translates to:
  /// **'Данные налогоплательщика'**
  String get fiscalSettingsTaxpayerInfo;

  /// No description provided for @fiscalSettingsVatSettings.
  ///
  /// In ru, this message translates to:
  /// **'Настройки НДС'**
  String get fiscalSettingsVatSettings;

  /// No description provided for @fiscalSettingsWebkassaLabel.
  ///
  /// In ru, this message translates to:
  /// **'WebKassa'**
  String get fiscalSettingsWebkassaLabel;

  /// No description provided for @fiscalSettingsWebkassaDesc.
  ///
  /// In ru, this message translates to:
  /// **'Облачный фискальный сервис'**
  String get fiscalSettingsWebkassaDesc;

  /// No description provided for @fiscalSettingsOfdLabel.
  ///
  /// In ru, this message translates to:
  /// **'OFD'**
  String get fiscalSettingsOfdLabel;

  /// No description provided for @fiscalSettingsOfdDesc.
  ///
  /// In ru, this message translates to:
  /// **'Оператор фискальных данных'**
  String get fiscalSettingsOfdDesc;

  /// No description provided for @fiscalSettingsNoneLabel.
  ///
  /// In ru, this message translates to:
  /// **'Без фискализации'**
  String get fiscalSettingsNoneLabel;

  /// No description provided for @fiscalSettingsNoneDesc.
  ///
  /// In ru, this message translates to:
  /// **'Чеки не отправляются в ОФД'**
  String get fiscalSettingsNoneDesc;

  /// No description provided for @fiscalSettingsOfdId.
  ///
  /// In ru, this message translates to:
  /// **'ID ОФД'**
  String get fiscalSettingsOfdId;

  /// No description provided for @fiscalSettingsOfdIdHint.
  ///
  /// In ru, this message translates to:
  /// **'Идентификатор ОФД'**
  String get fiscalSettingsOfdIdHint;

  /// No description provided for @fiscalSettingsOfdName.
  ///
  /// In ru, this message translates to:
  /// **'Название ОФД'**
  String get fiscalSettingsOfdName;

  /// No description provided for @fiscalSettingsOfdNameHint.
  ///
  /// In ru, this message translates to:
  /// **'WebKassa / ОФД.kz'**
  String get fiscalSettingsOfdNameHint;

  /// No description provided for @fiscalSettingsOfdHost.
  ///
  /// In ru, this message translates to:
  /// **'Адрес сервера ОФД'**
  String get fiscalSettingsOfdHost;

  /// No description provided for @fiscalSettingsOfdHostHint.
  ///
  /// In ru, this message translates to:
  /// **'https://api.webkassa.kz'**
  String get fiscalSettingsOfdHostHint;

  /// No description provided for @fiscalSettingsWebkassaActive.
  ///
  /// In ru, this message translates to:
  /// **'WebKassa активирована'**
  String get fiscalSettingsWebkassaActive;

  /// No description provided for @fiscalSettingsWebkassaInactive.
  ///
  /// In ru, this message translates to:
  /// **'WebKassa не активирована'**
  String get fiscalSettingsWebkassaInactive;

  /// No description provided for @fiscalSettingsCompanyName.
  ///
  /// In ru, this message translates to:
  /// **'Наименование'**
  String get fiscalSettingsCompanyName;

  /// No description provided for @fiscalSettingsCashBox.
  ///
  /// In ru, this message translates to:
  /// **'Касса'**
  String get fiscalSettingsCashBox;

  /// No description provided for @fiscalSettingsVatPayer.
  ///
  /// In ru, this message translates to:
  /// **'Плательщик НДС'**
  String get fiscalSettingsVatPayer;

  /// No description provided for @fiscalSettingsVatPayerSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Организация является плательщиком НДС (12%)'**
  String get fiscalSettingsVatPayerSubtitle;

  /// No description provided for @fiscalSettingsPrintVat.
  ///
  /// In ru, this message translates to:
  /// **'Печатать НДС на чеке'**
  String get fiscalSettingsPrintVat;

  /// No description provided for @fiscalSettingsPrintVatSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Отображать сумму НДС в чеке'**
  String get fiscalSettingsPrintVatSubtitle;

  /// No description provided for @fiscalOffsetSection.
  ///
  /// In ru, this message translates to:
  /// **'Сертификаты и аванс'**
  String get fiscalOffsetSection;

  /// No description provided for @fiscalOffsetCertificateSale.
  ///
  /// In ru, this message translates to:
  /// **'Чек при продаже сертификата'**
  String get fiscalOffsetCertificateSale;

  /// No description provided for @fiscalOffsetCertificateSaleSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Выбивать фискальный чек, когда покупают подарочный сертификат'**
  String get fiscalOffsetCertificateSaleSubtitle;

  /// No description provided for @fiscalOffsetLayout.
  ///
  /// In ru, this message translates to:
  /// **'Оплата сертификатом или авансом'**
  String get fiscalOffsetLayout;

  /// No description provided for @fiscalOffsetLayoutSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Как сумма зачёта попадает в чек оператора ОФД'**
  String get fiscalOffsetLayoutSubtitle;

  /// No description provided for @fiscalOffsetLayoutDiscount.
  ///
  /// In ru, this message translates to:
  /// **'Скидкой на товары'**
  String get fiscalOffsetLayoutDiscount;

  /// No description provided for @fiscalOffsetLayoutSurchargeOnly.
  ///
  /// In ru, this message translates to:
  /// **'Чек только на доплату'**
  String get fiscalOffsetLayoutSurchargeOnly;

  /// No description provided for @fiscalOffsetPrepaymentReceipt.
  ///
  /// In ru, this message translates to:
  /// **'Чек при приёме аванса'**
  String get fiscalOffsetPrepaymentReceipt;

  /// No description provided for @fiscalOffsetPrepaymentReceiptSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Выбивать фискальный чек, когда покупатель вносит аванс'**
  String get fiscalOffsetPrepaymentReceiptSubtitle;

  /// No description provided for @fiscalOffsetSaveError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось сохранить настройку'**
  String get fiscalOffsetSaveError;

  /// No description provided for @customerPaymentTender.
  ///
  /// In ru, this message translates to:
  /// **'Чем принято'**
  String get customerPaymentTender;

  /// No description provided for @fiscalSettingsVatRate.
  ///
  /// In ru, this message translates to:
  /// **'Ставка НДС: 12% (расчёт по формуле 3/28)'**
  String get fiscalSettingsVatRate;

  /// No description provided for @historyProductUcode.
  ///
  /// In ru, this message translates to:
  /// **'Товар #{ucode}'**
  String historyProductUcode(String ucode);

  /// No description provided for @historyRefundProductId.
  ///
  /// In ru, this message translates to:
  /// **'Товар возврата #{id}'**
  String historyRefundProductId(String id);

  /// No description provided for @historyAccountId.
  ///
  /// In ru, this message translates to:
  /// **'Счёт #{id}'**
  String historyAccountId(String id);

  /// No description provided for @historyLoadError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка загрузки: {error}'**
  String historyLoadError(String error);

  /// No description provided for @historyReceiptNo.
  ///
  /// In ru, this message translates to:
  /// **'Чек {number}'**
  String historyReceiptNo(String number);

  /// No description provided for @historySyncSynced.
  ///
  /// In ru, this message translates to:
  /// **'Синхр.'**
  String get historySyncSynced;

  /// No description provided for @historySyncPending.
  ///
  /// In ru, this message translates to:
  /// **'Ожид.'**
  String get historySyncPending;

  /// No description provided for @historySyncSending.
  ///
  /// In ru, this message translates to:
  /// **'Отпр.'**
  String get historySyncSending;

  /// No description provided for @historySyncDeferred.
  ///
  /// In ru, this message translates to:
  /// **'Отлож.'**
  String get historySyncDeferred;

  /// No description provided for @historySyncInProgress.
  ///
  /// In ru, this message translates to:
  /// **'В работе'**
  String get historySyncInProgress;

  /// No description provided for @historyClient.
  ///
  /// In ru, this message translates to:
  /// **'Клиент'**
  String get historyClient;

  /// No description provided for @historyFiscalization.
  ///
  /// In ru, this message translates to:
  /// **'Фискализация'**
  String get historyFiscalization;

  /// No description provided for @historyProducts.
  ///
  /// In ru, this message translates to:
  /// **'Товары'**
  String get historyProducts;

  /// No description provided for @historyPayment.
  ///
  /// In ru, this message translates to:
  /// **'Оплата'**
  String get historyPayment;

  /// No description provided for @historyNoProducts.
  ///
  /// In ru, this message translates to:
  /// **'Нет товаров'**
  String get historyNoProducts;

  /// No description provided for @historyNoPayments.
  ///
  /// In ru, this message translates to:
  /// **'Нет платежей'**
  String get historyNoPayments;

  /// No description provided for @historyPrintingReceipt.
  ///
  /// In ru, this message translates to:
  /// **'Печать чека {number}...'**
  String historyPrintingReceipt(String number);

  /// No description provided for @historyReceiptPrinted.
  ///
  /// In ru, this message translates to:
  /// **'Чек напечатан'**
  String get historyReceiptPrinted;

  /// No description provided for @historyPrintError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка печати'**
  String get historyPrintError;

  /// No description provided for @historyOperationType.
  ///
  /// In ru, this message translates to:
  /// **'Тип операции'**
  String get historyOperationType;

  /// No description provided for @historyFilterSales.
  ///
  /// In ru, this message translates to:
  /// **'Продажи'**
  String get historyFilterSales;

  /// No description provided for @historyFilterRefunds.
  ///
  /// In ru, this message translates to:
  /// **'Возвраты'**
  String get historyFilterRefunds;

  /// No description provided for @historySearchShort.
  ///
  /// In ru, this message translates to:
  /// **'Поиск...'**
  String get historySearchShort;

  /// No description provided for @historyFilters.
  ///
  /// In ru, this message translates to:
  /// **'Фильтры'**
  String get historyFilters;

  /// No description provided for @historyDateFrom.
  ///
  /// In ru, this message translates to:
  /// **'С'**
  String get historyDateFrom;

  /// No description provided for @historyDateTo.
  ///
  /// In ru, this message translates to:
  /// **'По'**
  String get historyDateTo;

  /// No description provided for @historyReset.
  ///
  /// In ru, this message translates to:
  /// **'Сбросить'**
  String get historyReset;

  /// No description provided for @historyApply.
  ///
  /// In ru, this message translates to:
  /// **'Применить'**
  String get historyApply;

  /// No description provided for @historySearchFull.
  ///
  /// In ru, this message translates to:
  /// **'Поиск по номеру чека, сумме...'**
  String get historySearchFull;

  /// No description provided for @historySyncStatus.
  ///
  /// In ru, this message translates to:
  /// **'Статус синхронизации'**
  String get historySyncStatus;

  /// No description provided for @historyReceiptColumn.
  ///
  /// In ru, this message translates to:
  /// **'Чек'**
  String get historyReceiptColumn;

  /// No description provided for @historySyncSyncedFull.
  ///
  /// In ru, this message translates to:
  /// **'Синхронизировано'**
  String get historySyncSyncedFull;

  /// No description provided for @historySyncPendingFull.
  ///
  /// In ru, this message translates to:
  /// **'Ожидает синхронизации'**
  String get historySyncPendingFull;

  /// No description provided for @historySyncSendingFull.
  ///
  /// In ru, this message translates to:
  /// **'Отправляется'**
  String get historySyncSendingFull;

  /// No description provided for @historySyncDeferredFull.
  ///
  /// In ru, this message translates to:
  /// **'Отложено'**
  String get historySyncDeferredFull;

  /// No description provided for @historySyncInProgressFull.
  ///
  /// In ru, this message translates to:
  /// **'В процессе'**
  String get historySyncInProgressFull;

  /// No description provided for @historyPaymentCash.
  ///
  /// In ru, this message translates to:
  /// **'Наличные'**
  String get historyPaymentCash;

  /// No description provided for @historyPaymentCard.
  ///
  /// In ru, this message translates to:
  /// **'Карта'**
  String get historyPaymentCard;

  /// No description provided for @historyPaymentMixed.
  ///
  /// In ru, this message translates to:
  /// **'Смешанная'**
  String get historyPaymentMixed;

  /// No description provided for @historyPaymentBonus.
  ///
  /// In ru, this message translates to:
  /// **'Бонусы'**
  String get historyPaymentBonus;

  /// No description provided for @historyPaymentDebt.
  ///
  /// In ru, this message translates to:
  /// **'В долг'**
  String get historyPaymentDebt;

  /// No description provided for @historyPaymentDiscount.
  ///
  /// In ru, this message translates to:
  /// **'Скидка'**
  String get historyPaymentDiscount;

  /// No description provided for @historyPaymentWithDiscount.
  ///
  /// In ru, this message translates to:
  /// **'Со скидкой'**
  String get historyPaymentWithDiscount;

  /// No description provided for @historyOfdFiscalized.
  ///
  /// In ru, this message translates to:
  /// **'Фискализирован'**
  String get historyOfdFiscalized;

  /// No description provided for @historyOfdError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка фискализации'**
  String get historyOfdError;

  /// No description provided for @historyOfdNotFiscalized.
  ///
  /// In ru, this message translates to:
  /// **'Не фискализирован'**
  String get historyOfdNotFiscalized;

  /// No description provided for @historyClearFilters.
  ///
  /// In ru, this message translates to:
  /// **'Сбросить фильтры'**
  String get historyClearFilters;

  /// No description provided for @historyRecordsRange.
  ///
  /// In ru, this message translates to:
  /// **'Записи {start}–{end} из {total}'**
  String historyRecordsRange(String start, String end, String total);

  /// No description provided for @historyFirstPage.
  ///
  /// In ru, this message translates to:
  /// **'Первая страница'**
  String get historyFirstPage;

  /// No description provided for @historyPrevious.
  ///
  /// In ru, this message translates to:
  /// **'Предыдущая'**
  String get historyPrevious;

  /// No description provided for @historyNextPage.
  ///
  /// In ru, this message translates to:
  /// **'Следующая'**
  String get historyNextPage;

  /// No description provided for @historyLastPage.
  ///
  /// In ru, this message translates to:
  /// **'Последняя страница'**
  String get historyLastPage;

  /// No description provided for @historyAmount.
  ///
  /// In ru, this message translates to:
  /// **'Сумма: {amount}'**
  String historyAmount(String amount);

  /// No description provided for @historyDate.
  ///
  /// In ru, this message translates to:
  /// **'Дата: {date}'**
  String historyDate(String date);

  /// No description provided for @historyPos.
  ///
  /// In ru, this message translates to:
  /// **'POS: {id}'**
  String historyPos(String id);

  /// No description provided for @historyClientName.
  ///
  /// In ru, this message translates to:
  /// **'Клиент: {name}'**
  String historyClientName(String name);

  /// No description provided for @historyFiscalYes.
  ///
  /// In ru, this message translates to:
  /// **'Да'**
  String get historyFiscalYes;

  /// No description provided for @historyFiscalNo.
  ///
  /// In ru, this message translates to:
  /// **'Нет'**
  String get historyFiscalNo;

  /// No description provided for @historyFiscalError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка'**
  String get historyFiscalError;

  /// No description provided for @shiftPrintZReport.
  ///
  /// In ru, this message translates to:
  /// **'Печать Z-отчёта'**
  String get shiftPrintZReport;

  /// No description provided for @shiftZReportQueued.
  ///
  /// In ru, this message translates to:
  /// **'Z-отчёт принят в очередь печати. Бумаги пока нет: она выйдет, когда принтер сможет. Задание ждёт 30 минут — посмотреть его можно в Настройках → Принтер'**
  String get shiftZReportQueued;

  /// No description provided for @shiftZReportAlreadyQueued.
  ///
  /// In ru, this message translates to:
  /// **'Z-отчёт уже сдан в печать — второй раз он не печатается'**
  String get shiftZReportAlreadyQueued;

  /// No description provided for @shiftZReportPrintFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось сдать Z-отчёт в печать'**
  String get shiftZReportPrintFailed;

  /// No description provided for @shiftFinishAllSales.
  ///
  /// In ru, this message translates to:
  /// **'Завершите все продажи'**
  String get shiftFinishAllSales;

  /// No description provided for @shiftCannotClose.
  ///
  /// In ru, this message translates to:
  /// **'Невозможно закрыть смену'**
  String get shiftCannotClose;

  /// No description provided for @shiftOpeningShift.
  ///
  /// In ru, this message translates to:
  /// **'Открытие смены'**
  String get shiftOpeningShift;

  /// No description provided for @shiftClosingShift.
  ///
  /// In ru, this message translates to:
  /// **'Закрытие смены'**
  String get shiftClosingShift;

  /// No description provided for @shiftEnterInitialAmount.
  ///
  /// In ru, this message translates to:
  /// **'Введите начальную сумму в кассе:'**
  String get shiftEnterInitialAmount;

  /// No description provided for @shiftDiscrepancyFound.
  ///
  /// In ru, this message translates to:
  /// **'Обнаружено расхождение'**
  String get shiftDiscrepancyFound;

  /// No description provided for @shiftDifferenceAmount.
  ///
  /// In ru, this message translates to:
  /// **'Разница: {amount}'**
  String shiftDifferenceAmount(String amount);

  /// No description provided for @shiftConfirmCloseQuestion.
  ///
  /// In ru, this message translates to:
  /// **'Вы уверены, что хотите закрыть смену?'**
  String get shiftConfirmCloseQuestion;

  /// No description provided for @shiftFixedAmount.
  ///
  /// In ru, this message translates to:
  /// **'Будет зафиксирована сумма: {amount}'**
  String shiftFixedAmount(String amount);

  /// No description provided for @shiftCloseWithDiscrepancy.
  ///
  /// In ru, this message translates to:
  /// **'Закрыть с расхождением'**
  String get shiftCloseWithDiscrepancy;

  /// No description provided for @shiftCashierLabel.
  ///
  /// In ru, this message translates to:
  /// **'Кассир'**
  String get shiftCashierLabel;

  /// No description provided for @shiftUnknown.
  ///
  /// In ru, this message translates to:
  /// **'Неизвестно'**
  String get shiftUnknown;

  /// No description provided for @shiftSystemTotal.
  ///
  /// In ru, this message translates to:
  /// **'Ожидается в кассе'**
  String get shiftSystemTotal;

  /// No description provided for @shiftEnteredTotal.
  ///
  /// In ru, this message translates to:
  /// **'Пересчитано'**
  String get shiftEnteredTotal;

  /// No description provided for @shiftCashOperations.
  ///
  /// In ru, this message translates to:
  /// **'Кассовые операции'**
  String get shiftCashOperations;

  /// No description provided for @shiftSalesLabel.
  ///
  /// In ru, this message translates to:
  /// **'Продажи'**
  String get shiftSalesLabel;

  /// No description provided for @shiftSalesTotal.
  ///
  /// In ru, this message translates to:
  /// **'Сумма продаж'**
  String get shiftSalesTotal;

  /// No description provided for @shiftCashSales.
  ///
  /// In ru, this message translates to:
  /// **'Наличные'**
  String get shiftCashSales;

  /// No description provided for @shiftCardSales.
  ///
  /// In ru, this message translates to:
  /// **'Карта'**
  String get shiftCardSales;

  /// No description provided for @shiftRefundsTotal.
  ///
  /// In ru, this message translates to:
  /// **'Возвраты'**
  String get shiftRefundsTotal;

  /// No description provided for @cashOpeningCount.
  ///
  /// In ru, this message translates to:
  /// **'Пересчёт при открытии'**
  String get cashOpeningCount;

  /// No description provided for @shiftShortage.
  ///
  /// In ru, this message translates to:
  /// **'Недостача'**
  String get shiftShortage;

  /// No description provided for @shiftSurplus.
  ///
  /// In ru, this message translates to:
  /// **'Излишек'**
  String get shiftSurplus;

  /// No description provided for @shiftBalances.
  ///
  /// In ru, this message translates to:
  /// **'Сходится'**
  String get shiftBalances;

  /// No description provided for @shiftCloseBlocked.
  ///
  /// In ru, this message translates to:
  /// **'Закрытие заблокировано'**
  String get shiftCloseBlocked;

  /// No description provided for @shiftActiveSalesCount.
  ///
  /// In ru, this message translates to:
  /// **'Активные продажи: {count}'**
  String shiftActiveSalesCount(int count);

  /// No description provided for @shiftPendingSalesCount.
  ///
  /// In ru, this message translates to:
  /// **'Отложенные продажи: {count}'**
  String shiftPendingSalesCount(int count);

  /// No description provided for @shiftFinishSalesBeforeClose.
  ///
  /// In ru, this message translates to:
  /// **'Завершите или отмените продажи перед закрытием смены'**
  String get shiftFinishSalesBeforeClose;

  /// No description provided for @shiftBillsTab.
  ///
  /// In ru, this message translates to:
  /// **'Купюры'**
  String get shiftBillsTab;

  /// No description provided for @shiftTotalTab.
  ///
  /// In ru, this message translates to:
  /// **'Общая сумма'**
  String get shiftTotalTab;

  /// No description provided for @shiftOperationsTab.
  ///
  /// In ru, this message translates to:
  /// **'Операции'**
  String get shiftOperationsTab;

  /// No description provided for @shiftAmountTab.
  ///
  /// In ru, this message translates to:
  /// **'Сумма'**
  String get shiftAmountTab;

  /// No description provided for @shiftBillCount.
  ///
  /// In ru, this message translates to:
  /// **'Пересчёт по купюрам'**
  String get shiftBillCount;

  /// No description provided for @shiftDifferenceLabel.
  ///
  /// In ru, this message translates to:
  /// **'Разница: '**
  String get shiftDifferenceLabel;

  /// No description provided for @supplySupplierRequired.
  ///
  /// In ru, this message translates to:
  /// **'Поставщик *'**
  String get supplySupplierRequired;

  /// No description provided for @supplyPaymentType.
  ///
  /// In ru, this message translates to:
  /// **'Тип оплаты'**
  String get supplyPaymentType;

  /// No description provided for @supplyFullPayment.
  ///
  /// In ru, this message translates to:
  /// **'Полная оплата'**
  String get supplyFullPayment;

  /// No description provided for @supplyAccountDebit.
  ///
  /// In ru, this message translates to:
  /// **'Списание со счёта'**
  String get supplyAccountDebit;

  /// No description provided for @supplyConsignment.
  ///
  /// In ru, this message translates to:
  /// **'Консигнация'**
  String get supplyConsignment;

  /// No description provided for @supplyDeferredPayment.
  ///
  /// In ru, this message translates to:
  /// **'Отсрочка платежа'**
  String get supplyDeferredPayment;

  /// No description provided for @supplyPaymentAccountRequired.
  ///
  /// In ru, this message translates to:
  /// **'Счёт оплаты *'**
  String get supplyPaymentAccountRequired;

  /// No description provided for @supplyAddProduct.
  ///
  /// In ru, this message translates to:
  /// **'Добавить товар'**
  String get supplyAddProduct;

  /// No description provided for @supplyBarcodeOrSku.
  ///
  /// In ru, this message translates to:
  /// **'Штрихкод или артикул'**
  String get supplyBarcodeOrSku;

  /// No description provided for @supplyProductsCount.
  ///
  /// In ru, this message translates to:
  /// **'Товары ({count})'**
  String supplyProductsCount(int count);

  /// No description provided for @supplyAmountValue.
  ///
  /// In ru, this message translates to:
  /// **'Сумма: {amount}'**
  String supplyAmountValue(String amount);

  /// No description provided for @supplyProductNotFound.
  ///
  /// In ru, this message translates to:
  /// **'Товар не найден'**
  String get supplyProductNotFound;

  /// No description provided for @supplyInvalidQuantity.
  ///
  /// In ru, this message translates to:
  /// **'Введите корректное количество'**
  String get supplyInvalidQuantity;

  /// No description provided for @supplySelectSupplierTitle.
  ///
  /// In ru, this message translates to:
  /// **'Выберите поставщика'**
  String get supplySelectSupplierTitle;

  /// No description provided for @supplySuppliersNotFound.
  ///
  /// In ru, this message translates to:
  /// **'Поставщики не найдены'**
  String get supplySuppliersNotFound;

  /// No description provided for @supplySelectAccountTitle.
  ///
  /// In ru, this message translates to:
  /// **'Выберите счёт'**
  String get supplySelectAccountTitle;

  /// No description provided for @supplyAccountsNotFound.
  ///
  /// In ru, this message translates to:
  /// **'Счета не найдены'**
  String get supplyAccountsNotFound;

  /// No description provided for @supplyAccountBalance.
  ///
  /// In ru, this message translates to:
  /// **'Баланс: {amount}'**
  String supplyAccountBalance(String amount);

  /// No description provided for @supplyProductNumber.
  ///
  /// In ru, this message translates to:
  /// **'Товар #{number}'**
  String supplyProductNumber(String number);

  /// No description provided for @supplyProductCountLabel.
  ///
  /// In ru, this message translates to:
  /// **'Товаров: {count}'**
  String supplyProductCountLabel(int count);

  /// No description provided for @supplyTotalLabel.
  ///
  /// In ru, this message translates to:
  /// **'Итого: {amount}'**
  String supplyTotalLabel(String amount);

  /// No description provided for @supplySavedSuccess.
  ///
  /// In ru, this message translates to:
  /// **'Приёмка сохранена. Товаров: {count}, сумма: {amount}'**
  String supplySavedSuccess(int count, String amount);

  /// No description provided for @supplyCancelConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Отменить приёмку?'**
  String get supplyCancelConfirm;

  /// No description provided for @supplyCancelMessage.
  ///
  /// In ru, this message translates to:
  /// **'Все введённые данные будут потеряны.'**
  String get supplyCancelMessage;

  /// No description provided for @supplyYesCancel.
  ///
  /// In ru, this message translates to:
  /// **'Да, отменить'**
  String get supplyYesCancel;

  /// No description provided for @supplySearchProduct.
  ///
  /// In ru, this message translates to:
  /// **'Поиск товара...'**
  String get supplySearchProduct;

  /// No description provided for @supplyAddProductsHint.
  ///
  /// In ru, this message translates to:
  /// **'Добавьте товары в приёмку'**
  String get supplyAddProductsHint;

  /// No description provided for @supplyScanOrSearch.
  ///
  /// In ru, this message translates to:
  /// **'Отсканируйте штрихкод или найдите товар'**
  String get supplyScanOrSearch;

  /// No description provided for @refundTotalAmount.
  ///
  /// In ru, this message translates to:
  /// **'Сумма возврата'**
  String get refundTotalAmount;

  /// No description provided for @refundPosLabel.
  ///
  /// In ru, this message translates to:
  /// **'Касса'**
  String get refundPosLabel;

  /// No description provided for @refundSelectedOfTotal.
  ///
  /// In ru, this message translates to:
  /// **'{selected} из {total}'**
  String refundSelectedOfTotal(String selected, String total);

  /// No description provided for @refundTotalProducts.
  ///
  /// In ru, this message translates to:
  /// **'Всего товаров'**
  String get refundTotalProducts;

  /// No description provided for @refundToReturn.
  ///
  /// In ru, this message translates to:
  /// **'К ВОЗВРАТУ'**
  String get refundToReturn;

  /// No description provided for @refundToReturnLabel.
  ///
  /// In ru, this message translates to:
  /// **'К возврату:'**
  String get refundToReturnLabel;

  /// No description provided for @refundAction.
  ///
  /// In ru, this message translates to:
  /// **'ВОЗВРАТ'**
  String get refundAction;

  /// No description provided for @refundSelectedItemsShort.
  ///
  /// In ru, this message translates to:
  /// **'{selected} из {total} поз.'**
  String refundSelectedItemsShort(String selected, String total);

  /// No description provided for @refundColumnName.
  ///
  /// In ru, this message translates to:
  /// **'Название'**
  String get refundColumnName;

  /// No description provided for @refundColumnQty.
  ///
  /// In ru, this message translates to:
  /// **'Кол-во'**
  String get refundColumnQty;

  /// No description provided for @refundEmptyHint.
  ///
  /// In ru, this message translates to:
  /// **'Загрузите чек или добавьте товары вручную'**
  String get refundEmptyHint;

  /// No description provided for @refundNoItemsShort.
  ///
  /// In ru, this message translates to:
  /// **'Нет товаров'**
  String get refundNoItemsShort;

  /// No description provided for @refundEmptyHintShort.
  ///
  /// In ru, this message translates to:
  /// **'Загрузите чек или\nдобавьте товары'**
  String get refundEmptyHintShort;

  /// No description provided for @refundSelectedCount.
  ///
  /// In ru, this message translates to:
  /// **'Выбрано позиций: {count}'**
  String refundSelectedCount(String count);

  /// No description provided for @refundAmountValue.
  ///
  /// In ru, this message translates to:
  /// **'Сумма возврата: {amount}'**
  String refundAmountValue(String amount);

  /// No description provided for @refundSuccess.
  ///
  /// In ru, this message translates to:
  /// **'Возврат успешно проведён'**
  String get refundSuccess;

  /// No description provided for @paymentAmountDue.
  ///
  /// In ru, this message translates to:
  /// **'К оплате'**
  String get paymentAmountDue;

  /// No description provided for @paymentTotalDue.
  ///
  /// In ru, this message translates to:
  /// **'Итого к оплате'**
  String get paymentTotalDue;

  /// No description provided for @paymentCashLabel.
  ///
  /// In ru, this message translates to:
  /// **'Наличными'**
  String get paymentCashLabel;

  /// No description provided for @paymentReceived.
  ///
  /// In ru, this message translates to:
  /// **'Получено'**
  String get paymentReceived;

  /// No description provided for @paymentRemainingLabel.
  ///
  /// In ru, this message translates to:
  /// **'Осталось'**
  String get paymentRemainingLabel;

  /// No description provided for @paymentCardAmount.
  ///
  /// In ru, this message translates to:
  /// **'Оплата картой на сумму {amount}'**
  String paymentCardAmount(String amount);

  /// No description provided for @paymentLoyaltyProgram.
  ///
  /// In ru, this message translates to:
  /// **'Программа лояльности'**
  String get paymentLoyaltyProgram;

  /// No description provided for @paymentPhoneNumber.
  ///
  /// In ru, this message translates to:
  /// **'Номер телефона'**
  String get paymentPhoneNumber;

  /// No description provided for @paymentAvailableBonus.
  ///
  /// In ru, this message translates to:
  /// **'Доступно бонусов:'**
  String get paymentAvailableBonus;

  /// No description provided for @paymentUseBonuses.
  ///
  /// In ru, this message translates to:
  /// **'Использовать бонусы'**
  String get paymentUseBonuses;

  /// No description provided for @paymentBonusToDeduct.
  ///
  /// In ru, this message translates to:
  /// **'К списанию: {amount} бонусов'**
  String paymentBonusToDeduct(String amount);

  /// No description provided for @paymentSuccessMessage.
  ///
  /// In ru, this message translates to:
  /// **'Оплата успешна'**
  String get paymentSuccessMessage;

  /// No description provided for @paymentRefundButton.
  ///
  /// In ru, this message translates to:
  /// **'ВЕРНУТЬ'**
  String get paymentRefundButton;

  /// No description provided for @paymentPayButton.
  ///
  /// In ru, this message translates to:
  /// **'ОПЛАТИТЬ'**
  String get paymentPayButton;

  /// No description provided for @syncWidgetRetry.
  ///
  /// In ru, this message translates to:
  /// **'Повторить'**
  String get syncWidgetRetry;

  /// No description provided for @syncWidgetLastSync.
  ///
  /// In ru, this message translates to:
  /// **'Последняя синхронизация: {time}'**
  String syncWidgetLastSync(String time);

  /// No description provided for @syncWidgetRecordsCount.
  ///
  /// In ru, this message translates to:
  /// **'{count} записей'**
  String syncWidgetRecordsCount(int count);

  /// No description provided for @syncWidgetWaiting.
  ///
  /// In ru, this message translates to:
  /// **'Ожидает'**
  String get syncWidgetWaiting;

  /// No description provided for @syncWidgetSynced.
  ///
  /// In ru, this message translates to:
  /// **'Синхронизировано'**
  String get syncWidgetSynced;

  /// No description provided for @syncWidgetJustNow.
  ///
  /// In ru, this message translates to:
  /// **'только что'**
  String get syncWidgetJustNow;

  /// No description provided for @syncWidgetMinutesAgo.
  ///
  /// In ru, this message translates to:
  /// **'{minutes} мин. назад'**
  String syncWidgetMinutesAgo(int minutes);

  /// No description provided for @syncWidgetHoursAgo.
  ///
  /// In ru, this message translates to:
  /// **'{hours} ч. назад'**
  String syncWidgetHoursAgo(int hours);

  /// No description provided for @syncWidgetDaysAgo.
  ///
  /// In ru, this message translates to:
  /// **'{days} дн. назад'**
  String syncWidgetDaysAgo(int days);

  /// No description provided for @syncWidgetConnecting.
  ///
  /// In ru, this message translates to:
  /// **'Подключение к серверу...'**
  String get syncWidgetConnecting;

  /// No description provided for @syncWidgetSyncingProducts.
  ///
  /// In ru, this message translates to:
  /// **'Синхронизация товаров...'**
  String get syncWidgetSyncingProducts;

  /// No description provided for @syncWidgetSyncingSales.
  ///
  /// In ru, this message translates to:
  /// **'Синхронизация продаж...'**
  String get syncWidgetSyncingSales;

  /// No description provided for @syncWidgetSyncingAgents.
  ///
  /// In ru, this message translates to:
  /// **'Синхронизация контрагентов...'**
  String get syncWidgetSyncingAgents;

  /// No description provided for @syncWidgetSyncingPrices.
  ///
  /// In ru, this message translates to:
  /// **'Синхронизация цен...'**
  String get syncWidgetSyncingPrices;

  /// No description provided for @syncWidgetFinishing.
  ///
  /// In ru, this message translates to:
  /// **'Завершение...'**
  String get syncWidgetFinishing;

  /// No description provided for @updateDialogUpdating.
  ///
  /// In ru, this message translates to:
  /// **'Обновление...'**
  String get updateDialogUpdating;

  /// No description provided for @updateDialogAvailable.
  ///
  /// In ru, this message translates to:
  /// **'Доступно обновление'**
  String get updateDialogAvailable;

  /// No description provided for @updateDialogAutoUpdate.
  ///
  /// In ru, this message translates to:
  /// **'Автоматическое обновление через {seconds} сек'**
  String updateDialogAutoUpdate(int seconds);

  /// No description provided for @updateDialogUpdateNow.
  ///
  /// In ru, this message translates to:
  /// **'Обновить сейчас'**
  String get updateDialogUpdateNow;

  /// No description provided for @updateDialogLater.
  ///
  /// In ru, this message translates to:
  /// **'Позже'**
  String get updateDialogLater;

  /// No description provided for @updateDialogSkip.
  ///
  /// In ru, this message translates to:
  /// **'Пропустить'**
  String get updateDialogSkip;

  /// No description provided for @updateDialogUpdate.
  ///
  /// In ru, this message translates to:
  /// **'Обновить'**
  String get updateDialogUpdate;

  /// No description provided for @storeUpdateVersion.
  ///
  /// In ru, this message translates to:
  /// **'Версия {version}'**
  String storeUpdateVersion(String version);

  /// No description provided for @storeUpdateNewVersionAvailable.
  ///
  /// In ru, this message translates to:
  /// **'Новая версия приложения доступна в {storeName}.'**
  String storeUpdateNewVersionAvailable(String storeName);

  /// No description provided for @storeUpdateWhatsNew.
  ///
  /// In ru, this message translates to:
  /// **'Что нового:'**
  String get storeUpdateWhatsNew;

  /// No description provided for @storeUpdateRequired.
  ///
  /// In ru, this message translates to:
  /// **'Это обязательное обновление'**
  String get storeUpdateRequired;

  /// No description provided for @storeUpdateGoTo.
  ///
  /// In ru, this message translates to:
  /// **'Перейти в {storeName}'**
  String storeUpdateGoTo(String storeName);

  /// No description provided for @storeUpdateButton.
  ///
  /// In ru, this message translates to:
  /// **'ОБНОВИТЬ'**
  String get storeUpdateButton;

  /// No description provided for @storeUpdateDownloaded.
  ///
  /// In ru, this message translates to:
  /// **'Обновление загружено'**
  String get storeUpdateDownloaded;

  /// No description provided for @storeUpdateReadyToInstall.
  ///
  /// In ru, this message translates to:
  /// **'Обновление загружено и готово к установке.\nУстановить сейчас? Приложение будет перезапущено.'**
  String get storeUpdateReadyToInstall;

  /// No description provided for @storeUpdateInstall.
  ///
  /// In ru, this message translates to:
  /// **'УСТАНОВИТЬ'**
  String get storeUpdateInstall;

  /// No description provided for @storeUpdateDownloading.
  ///
  /// In ru, this message translates to:
  /// **'Загрузка обновления...'**
  String get storeUpdateDownloading;

  /// No description provided for @storeUpdateReadyShort.
  ///
  /// In ru, this message translates to:
  /// **'Обновление готово к установке'**
  String get storeUpdateReadyShort;

  /// No description provided for @versionConflictTitle.
  ///
  /// In ru, this message translates to:
  /// **'Конфликт версий'**
  String get versionConflictTitle;

  /// No description provided for @versionConflictDescription.
  ///
  /// In ru, this message translates to:
  /// **'Обнаружен конфликт версий приложения.'**
  String get versionConflictDescription;

  /// No description provided for @versionConflictCurrent.
  ///
  /// In ru, this message translates to:
  /// **'Текущая версия'**
  String get versionConflictCurrent;

  /// No description provided for @versionConflictFound.
  ///
  /// In ru, this message translates to:
  /// **'Найденная версия'**
  String get versionConflictFound;

  /// No description provided for @versionConflictChooseAction.
  ///
  /// In ru, this message translates to:
  /// **'Выберите действие:'**
  String get versionConflictChooseAction;

  /// No description provided for @versionConflictOpenFolder.
  ///
  /// In ru, this message translates to:
  /// **'Открыть в папке'**
  String get versionConflictOpenFolder;

  /// No description provided for @versionConflictPreviousVersion.
  ///
  /// In ru, this message translates to:
  /// **'Прежняя версия'**
  String get versionConflictPreviousVersion;

  /// No description provided for @versionConflictContinue.
  ///
  /// In ru, this message translates to:
  /// **'Продолжить'**
  String get versionConflictContinue;

  /// No description provided for @restoreLoadingBackups.
  ///
  /// In ru, this message translates to:
  /// **'Загрузка бэкапов...'**
  String get restoreLoadingBackups;

  /// No description provided for @restoreSearchingBackups.
  ///
  /// In ru, this message translates to:
  /// **'Поиск бэкапов...'**
  String get restoreSearchingBackups;

  /// No description provided for @restoreLoadError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка загрузки: {error}'**
  String restoreLoadError(String error);

  /// No description provided for @restoreRestoring.
  ///
  /// In ru, this message translates to:
  /// **'Восстановление...'**
  String get restoreRestoring;

  /// No description provided for @restoreRestoreError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка восстановления'**
  String get restoreRestoreError;

  /// No description provided for @restoreRestoreFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось восстановить из бэкапа'**
  String get restoreRestoreFailed;

  /// No description provided for @restoreTitle.
  ///
  /// In ru, this message translates to:
  /// **'Восстановление'**
  String get restoreTitle;

  /// No description provided for @restoreChooseMethod.
  ///
  /// In ru, this message translates to:
  /// **'Выберите способ настройки'**
  String get restoreChooseMethod;

  /// No description provided for @restoreSetupNewPos.
  ///
  /// In ru, this message translates to:
  /// **'Настроить новую кассу'**
  String get restoreSetupNewPos;

  /// No description provided for @restoreNoBackups.
  ///
  /// In ru, this message translates to:
  /// **'Бэкапы не найдены'**
  String get restoreNoBackups;

  /// No description provided for @restoreSetupAsNew.
  ///
  /// In ru, this message translates to:
  /// **'Настройте кассу как новую'**
  String get restoreSetupAsNew;

  /// No description provided for @restoreFoundBackups.
  ///
  /// In ru, this message translates to:
  /// **'Найденные бэкапы:'**
  String get restoreFoundBackups;

  /// No description provided for @agentSearchByNameOrPhone.
  ///
  /// In ru, this message translates to:
  /// **'Поиск по имени или телефону...'**
  String get agentSearchByNameOrPhone;

  /// No description provided for @agentOnlyWithDebt.
  ///
  /// In ru, this message translates to:
  /// **'Только с долгом'**
  String get agentOnlyWithDebt;

  /// No description provided for @agentTypeTooltip.
  ///
  /// In ru, this message translates to:
  /// **'Тип'**
  String get agentTypeTooltip;

  /// No description provided for @agentBinLabel.
  ///
  /// In ru, this message translates to:
  /// **'БИН: {bin}'**
  String agentBinLabel(String bin);

  /// No description provided for @agentSelectedMessage.
  ///
  /// In ru, this message translates to:
  /// **'Выбран: {name}'**
  String agentSelectedMessage(String name);

  /// No description provided for @agentFoundCount.
  ///
  /// In ru, this message translates to:
  /// **'Найдено: {count}'**
  String agentFoundCount(int count);

  /// No description provided for @agentEnterNameOrPhoneToSearch.
  ///
  /// In ru, this message translates to:
  /// **'Введите имя или телефон для поиска'**
  String get agentEnterNameOrPhoneToSearch;

  /// No description provided for @agentNotFound.
  ///
  /// In ru, this message translates to:
  /// **'Клиенты не найдены'**
  String get agentNotFound;

  /// No description provided for @agentSearchClients.
  ///
  /// In ru, this message translates to:
  /// **'Поиск клиентов'**
  String get agentSearchClients;

  /// No description provided for @agentNotFoundShort.
  ///
  /// In ru, this message translates to:
  /// **'Не найдено'**
  String get agentNotFoundShort;

  /// No description provided for @agentEnterNameOrPhone.
  ///
  /// In ru, this message translates to:
  /// **'Введите имя или телефон'**
  String get agentEnterNameOrPhone;

  /// No description provided for @agentEnterCustomerName.
  ///
  /// In ru, this message translates to:
  /// **'Введите имя клиента'**
  String get agentEnterCustomerName;

  /// No description provided for @agentDeletedCustomerPhone.
  ///
  /// In ru, this message translates to:
  /// **'Клиент с таким телефоном был удалён'**
  String get agentDeletedCustomerPhone;

  /// No description provided for @agentWantRestore.
  ///
  /// In ru, this message translates to:
  /// **'Хотите восстановить?'**
  String get agentWantRestore;

  /// No description provided for @agentDeleteCustomerTitle.
  ///
  /// In ru, this message translates to:
  /// **'Удалить клиента?'**
  String get agentDeleteCustomerTitle;

  /// No description provided for @agentDeleteConfirmMessage.
  ///
  /// In ru, this message translates to:
  /// **'Вы уверены, что хотите удалить \"{name}\"?'**
  String agentDeleteConfirmMessage(String name);

  /// No description provided for @agentCustomerDeleted.
  ///
  /// In ru, this message translates to:
  /// **'Клиент \"{name}\" удалён'**
  String agentCustomerDeleted(String name);

  /// No description provided for @cashOpTitle.
  ///
  /// In ru, this message translates to:
  /// **'Кассовая операция'**
  String get cashOpTitle;

  /// No description provided for @cashOpComment.
  ///
  /// In ru, this message translates to:
  /// **'Комментарий'**
  String get cashOpComment;

  /// No description provided for @cashOpCommentRequired.
  ///
  /// In ru, this message translates to:
  /// **'Комментарий *'**
  String get cashOpCommentRequired;

  /// No description provided for @cashOpCommentHint.
  ///
  /// In ru, this message translates to:
  /// **'Введите комментарий...'**
  String get cashOpCommentHint;

  /// No description provided for @cashOpError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка: {error}'**
  String cashOpError(String error);

  /// No description provided for @cashOpOperationType.
  ///
  /// In ru, this message translates to:
  /// **'Тип операции'**
  String get cashOpOperationType;

  /// No description provided for @cashOpExpense.
  ///
  /// In ru, this message translates to:
  /// **'Расход'**
  String get cashOpExpense;

  /// No description provided for @cashOpDividend.
  ///
  /// In ru, this message translates to:
  /// **'Изъятие'**
  String get cashOpDividend;

  /// No description provided for @saleReceiptTotal.
  ///
  /// In ru, this message translates to:
  /// **'Итого по чеку'**
  String get saleReceiptTotal;

  /// No description provided for @salePay.
  ///
  /// In ru, this message translates to:
  /// **'ОПЛАТИТЬ'**
  String get salePay;

  /// No description provided for @saleTotalColon.
  ///
  /// In ru, this message translates to:
  /// **'Итого:'**
  String get saleTotalColon;

  /// No description provided for @salePositionsAndQuantity.
  ///
  /// In ru, this message translates to:
  /// **'{count} поз. / {qty} шт.'**
  String salePositionsAndQuantity(int count, String qty);

  /// No description provided for @saleWholesale.
  ///
  /// In ru, this message translates to:
  /// **'ОПТ'**
  String get saleWholesale;

  /// No description provided for @saleRetail.
  ///
  /// In ru, this message translates to:
  /// **'Розница'**
  String get saleRetail;

  /// No description provided for @syncPreparing.
  ///
  /// In ru, this message translates to:
  /// **'Подготовка...'**
  String get syncPreparing;

  /// Отказ кассы на операции возврата — текст причины приходит от кассы
  ///
  /// In ru, this message translates to:
  /// **'Возврат не выполнен: {reason}'**
  String refundRefused(String reason);

  /// No description provided for @errorSaveFailed.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка сохранения: {details}'**
  String errorSaveFailed(String details);

  /// No description provided for @errorSaveFailedGeneric.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка сохранения'**
  String get errorSaveFailedGeneric;

  /// No description provided for @errorLoadFailed.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка загрузки данных: {details}'**
  String errorLoadFailed(String details);

  /// No description provided for @errorLoadFailedGeneric.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка загрузки данных'**
  String get errorLoadFailedGeneric;

  /// No description provided for @errorSearchFailed.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка поиска: {details}'**
  String errorSearchFailed(String details);

  /// No description provided for @errorSearchFailedGeneric.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка поиска'**
  String get errorSearchFailedGeneric;

  /// No description provided for @errorUnknownGeneric.
  ///
  /// In ru, this message translates to:
  /// **'Неизвестная ошибка'**
  String get errorUnknownGeneric;

  /// No description provided for @errorRefusalUnknownCode.
  ///
  /// In ru, this message translates to:
  /// **'неизвестная причина (код {code})'**
  String errorRefusalUnknownCode(String code);

  /// No description provided for @errorReasonUnknown.
  ///
  /// In ru, this message translates to:
  /// **'неизвестная причина'**
  String get errorReasonUnknown;

  /// No description provided for @errorFillRequired.
  ///
  /// In ru, this message translates to:
  /// **'Заполните все обязательные поля'**
  String get errorFillRequired;

  /// No description provided for @errorNoUsers.
  ///
  /// In ru, this message translates to:
  /// **'Нет зарегистрированных пользователей'**
  String get errorNoUsers;

  /// No description provided for @errorSelectUser.
  ///
  /// In ru, this message translates to:
  /// **'Выберите пользователя'**
  String get errorSelectUser;

  /// No description provided for @errorPinTooShort.
  ///
  /// In ru, this message translates to:
  /// **'Введите PIN-код (минимум 4 цифры)'**
  String get errorPinTooShort;

  /// No description provided for @errorRsaNotConfigured.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка: RSA ключ не настроен. Обратитесь к администратору.'**
  String get errorRsaNotConfigured;

  /// No description provided for @errorWrongPin.
  ///
  /// In ru, this message translates to:
  /// **'Неверный PIN-код'**
  String get errorWrongPin;

  /// No description provided for @errorAmbiguousPin.
  ///
  /// In ru, this message translates to:
  /// **'Этот PIN-код совпадает у нескольких кассиров. Выберите своё имя и войдите по нему.'**
  String get errorAmbiguousPin;

  /// No description provided for @errorNoPinSet.
  ///
  /// In ru, this message translates to:
  /// **'У этого кассира не задан PIN-код. Обратитесь к администратору, чтобы его установить.'**
  String get errorNoPinSet;

  /// No description provided for @errorWalkUpDisabled.
  ///
  /// In ru, this message translates to:
  /// **'Вход без выбора имени отключён на этой точке. Выберите своё имя из списка.'**
  String get errorWalkUpDisabled;

  /// No description provided for @errorCredentialUnreadable.
  ///
  /// In ru, this message translates to:
  /// **'Запись PIN-кода повреждена. Обратитесь к администратору — набрать код заново не поможет.'**
  String get errorCredentialUnreadable;

  /// No description provided for @errorAuthUnknown.
  ///
  /// In ru, this message translates to:
  /// **'Касса не смогла ответить на попытку входа. Попробуйте ещё раз.'**
  String get errorAuthUnknown;

  /// No description provided for @errorTillNotConfigured.
  ///
  /// In ru, this message translates to:
  /// **'Касса ещё не настроена — вход невозможен, пока не пройден мастер настройки.'**
  String get errorTillNotConfigured;

  /// No description provided for @errorTillNotConfiguredSale.
  ///
  /// In ru, this message translates to:
  /// **'Касса не настроена — чек начать нельзя. Обратитесь к администратору: нужно пройти мастер настройки.'**
  String get errorTillNotConfiguredSale;

  /// No description provided for @errorNotAllowed.
  ///
  /// In ru, this message translates to:
  /// **'Недостаточно прав для этого действия. Обратитесь к администратору.'**
  String get errorNotAllowed;

  /// No description provided for @errorNoSaleModule.
  ///
  /// In ru, this message translates to:
  /// **'Эта касса не умеет вести чек: модуль продажи не собран. Обратитесь к администратору.'**
  String get errorNoSaleModule;

  /// No description provided for @errorTerminalInBody.
  ///
  /// In ru, this message translates to:
  /// **'Терминал обратился к кассе неверно. Обновите приложение на рабочем месте.'**
  String get errorTerminalInBody;

  /// No description provided for @errorWholesaleInStart.
  ///
  /// In ru, this message translates to:
  /// **'Оптовый чек так не начинается. Начните обычный чек и включите опт отдельной кнопкой.'**
  String get errorWholesaleInStart;

  /// No description provided for @errorTerminalLimitReached.
  ///
  /// In ru, this message translates to:
  /// **'На этой кассе уже заведено максимум терминалов. Обратитесь к администратору, чтобы освободить место.'**
  String get errorTerminalLimitReached;

  /// No description provided for @errorPairingCodeInvalid.
  ///
  /// In ru, this message translates to:
  /// **'Код привязки не подошёл — просрочен, уже использован или введён неверно. Получите новый код у оператора кассы.'**
  String get errorPairingCodeInvalid;

  /// No description provided for @errorTerminalSecretInvalid.
  ///
  /// In ru, this message translates to:
  /// **'Привязка этого устройства больше не действует — возможно, терминал удалили на кассе. Введите новый код привязки.'**
  String get errorTerminalSecretInvalid;

  /// No description provided for @errorSessionExpired.
  ///
  /// In ru, this message translates to:
  /// **'Сеанс истёк — войдите снова.'**
  String get errorSessionExpired;

  /// No description provided for @errorSessionEnded.
  ///
  /// In ru, this message translates to:
  /// **'Сеанс завершён на кассе — войдите снова.'**
  String get errorSessionEnded;

  /// No description provided for @errorSaleNotInitialized.
  ///
  /// In ru, this message translates to:
  /// **'Продажа не инициализирована'**
  String get errorSaleNotInitialized;

  /// No description provided for @errorReceiptEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Чек пуст'**
  String get errorReceiptEmpty;

  /// No description provided for @errorDeferredNotFound.
  ///
  /// In ru, this message translates to:
  /// **'Отложенный чек не найден'**
  String get errorDeferredNotFound;

  /// No description provided for @errorCartStale.
  ///
  /// In ru, this message translates to:
  /// **'Чек изменился, пока вы набирали. Экран обновлён — повторите последнее действие.'**
  String get errorCartStale;

  /// No description provided for @errorCartWrongReceipt.
  ///
  /// In ru, this message translates to:
  /// **'Этот чек больше не в работе. Начните новый чек или поднимите отложенный.'**
  String get errorCartWrongReceipt;

  /// No description provided for @errorCartNotStarted.
  ///
  /// In ru, this message translates to:
  /// **'Чек ещё не начат. Начните новый чек или поднимите отложенный.'**
  String get errorCartNotStarted;

  /// No description provided for @errorLineNotFound.
  ///
  /// In ru, this message translates to:
  /// **'Этой строки в чеке больше нет. Обновите чек и повторите.'**
  String get errorLineNotFound;

  /// No description provided for @errorInvalidAmount.
  ///
  /// In ru, this message translates to:
  /// **'Недопустимое значение. Сумма не может быть отрицательной, а скидка — больше 100%.'**
  String get errorInvalidAmount;

  /// No description provided for @errorDeferredTaken.
  ///
  /// In ru, this message translates to:
  /// **'Этот отложенный чек уже поднят на другом рабочем месте.'**
  String get errorDeferredTaken;

  /// No description provided for @errorCartNotEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Сначала завершите или отложите текущий чек — поднять отложенный поверх него нельзя.'**
  String get errorCartNotEmpty;

  /// No description provided for @errorSaleNotStarted.
  ///
  /// In ru, this message translates to:
  /// **'Касса не смогла начать чек и не назвала причину. Попробуйте ещё раз.'**
  String get errorSaleNotStarted;

  /// No description provided for @errorShiftNotOpen.
  ///
  /// In ru, this message translates to:
  /// **'Смена не открыта. Откройте смену на кассе.'**
  String get errorShiftNotOpen;

  /// No description provided for @errorCardTerminalMisconfigured.
  ///
  /// In ru, this message translates to:
  /// **'Платёжный терминал этого рабочего места настроен неверно. Проверьте привязку в настройках оборудования.'**
  String get errorCardTerminalMisconfigured;

  /// No description provided for @errorReceiptNotFound.
  ///
  /// In ru, this message translates to:
  /// **'Чек #{receiptNo} не найден'**
  String errorReceiptNotFound(String receiptNo);

  /// No description provided for @errorReceiptNotFoundGeneric.
  ///
  /// In ru, this message translates to:
  /// **'Чек не найден'**
  String get errorReceiptNotFoundGeneric;

  /// No description provided for @errorNotAuthorized.
  ///
  /// In ru, this message translates to:
  /// **'Пользователь не авторизован'**
  String get errorNotAuthorized;

  /// No description provided for @errorSupplierNotFound.
  ///
  /// In ru, this message translates to:
  /// **'Поставщик не найден'**
  String get errorSupplierNotFound;

  /// No description provided for @errorAccountNotFound.
  ///
  /// In ru, this message translates to:
  /// **'Счёт не найден'**
  String get errorAccountNotFound;

  /// No description provided for @errorProductNotFound.
  ///
  /// In ru, this message translates to:
  /// **'Товар не найден: {details}'**
  String errorProductNotFound(String details);

  /// No description provided for @errorProductNotFoundGeneric.
  ///
  /// In ru, this message translates to:
  /// **'Товар не найден'**
  String get errorProductNotFoundGeneric;

  /// No description provided for @errorNameRequired.
  ///
  /// In ru, this message translates to:
  /// **'Имя обязательно'**
  String get errorNameRequired;

  /// No description provided for @errorNameTooShort.
  ///
  /// In ru, this message translates to:
  /// **'Минимум 2 символа'**
  String get errorNameTooShort;

  /// No description provided for @errorPhoneInvalid.
  ///
  /// In ru, this message translates to:
  /// **'Неверный формат телефона'**
  String get errorPhoneInvalid;

  /// No description provided for @errorBinInvalid.
  ///
  /// In ru, this message translates to:
  /// **'БИН/ИИН должен содержать 12 цифр'**
  String get errorBinInvalid;

  /// No description provided for @errorPhoneExists.
  ///
  /// In ru, this message translates to:
  /// **'Клиент с таким телефоном уже существует'**
  String get errorPhoneExists;

  /// No description provided for @errorShiftOpenFailed.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка открытия смены: {details}'**
  String errorShiftOpenFailed(String details);

  /// No description provided for @errorShiftOpenFailedGeneric.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка открытия смены'**
  String get errorShiftOpenFailedGeneric;

  /// No description provided for @errorShiftCloseFailed.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка закрытия смены: {details}'**
  String errorShiftCloseFailed(String details);

  /// No description provided for @errorShiftCloseFailedGeneric.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка закрытия смены'**
  String get errorShiftCloseFailedGeneric;

  /// No description provided for @errorShiftLoadFailed.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка загрузки данных смены: {details}'**
  String errorShiftLoadFailed(String details);

  /// No description provided for @errorShiftLoadFailedGeneric.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка загрузки данных смены'**
  String get errorShiftLoadFailedGeneric;

  /// No description provided for @errorPaymentConfig.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось сформировать платёж. Проверьте настройки счетов.'**
  String get errorPaymentConfig;

  /// No description provided for @errorSaleSaveFailed.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка сохранения продажи'**
  String get errorSaleSaveFailed;

  /// No description provided for @errorInventoryCannotComplete.
  ///
  /// In ru, this message translates to:
  /// **'Невозможно завершить'**
  String get errorInventoryCannotComplete;

  /// No description provided for @errorNoProducts.
  ///
  /// In ru, this message translates to:
  /// **'Нет товаров для списания'**
  String get errorNoProducts;

  /// No description provided for @errorSelectCountry.
  ///
  /// In ru, this message translates to:
  /// **'Выберите страну'**
  String get errorSelectCountry;

  /// No description provided for @errorEnterOrgName.
  ///
  /// In ru, this message translates to:
  /// **'Введите название организации'**
  String get errorEnterOrgName;

  /// No description provided for @errorEnterTaxId.
  ///
  /// In ru, this message translates to:
  /// **'Введите {label}'**
  String errorEnterTaxId(String label);

  /// No description provided for @errorEnterTaxIdGeneric.
  ///
  /// In ru, this message translates to:
  /// **'Введите налоговый номер'**
  String get errorEnterTaxIdGeneric;

  /// No description provided for @errorTaxIdLength.
  ///
  /// In ru, this message translates to:
  /// **'{info}'**
  String errorTaxIdLength(String info);

  /// No description provided for @errorTaxIdLengthGeneric.
  ///
  /// In ru, this message translates to:
  /// **'Неверная длина налогового номера'**
  String get errorTaxIdLengthGeneric;

  /// No description provided for @errorEnterPosName.
  ///
  /// In ru, this message translates to:
  /// **'Введите название кассы'**
  String get errorEnterPosName;

  /// No description provided for @errorFillWebkassa.
  ///
  /// In ru, this message translates to:
  /// **'Заполните все поля WebKassa'**
  String get errorFillWebkassa;

  /// No description provided for @errorFillOfd.
  ///
  /// In ru, this message translates to:
  /// **'Заполните все поля ОФД'**
  String get errorFillOfd;

  /// No description provided for @errorEnterKaspiIp.
  ///
  /// In ru, this message translates to:
  /// **'Введите IP-адрес терминала Kaspi'**
  String get errorEnterKaspiIp;

  /// No description provided for @errorEnterAdminName.
  ///
  /// In ru, this message translates to:
  /// **'Введите имя администратора'**
  String get errorEnterAdminName;

  /// No description provided for @errorAdminPinShort.
  ///
  /// In ru, this message translates to:
  /// **'PIN администратора должен содержать минимум 4 цифры'**
  String get errorAdminPinShort;

  /// No description provided for @errorSellerPinShort.
  ///
  /// In ru, this message translates to:
  /// **'PIN продавца должен содержать минимум 4 цифры'**
  String get errorSellerPinShort;

  /// No description provided for @errorCheckFailed.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка проверки: {details}'**
  String errorCheckFailed(String details);

  /// No description provided for @errorCheckFailedGeneric.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка проверки'**
  String get errorCheckFailedGeneric;

  /// No description provided for @errorTelegramNotInitialized.
  ///
  /// In ru, this message translates to:
  /// **'TelegramInitializer не инициализирован'**
  String get errorTelegramNotInitialized;

  /// No description provided for @errorTelegramAuthNotInitialized.
  ///
  /// In ru, this message translates to:
  /// **'TelegramAuthService не инициализирован'**
  String get errorTelegramAuthNotInitialized;

  /// No description provided for @errorPhoneSendFailed.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка отправки номера: {details}'**
  String errorPhoneSendFailed(String details);

  /// No description provided for @errorPhoneSendFailedGeneric.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка отправки номера'**
  String get errorPhoneSendFailedGeneric;

  /// No description provided for @errorQrAuthFailed.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка QR авторизации: {details}'**
  String errorQrAuthFailed(String details);

  /// No description provided for @errorQrAuthFailedGeneric.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка QR авторизации'**
  String get errorQrAuthFailedGeneric;

  /// No description provided for @errorWrongCode.
  ///
  /// In ru, this message translates to:
  /// **'Неверный код: {details}'**
  String errorWrongCode(String details);

  /// No description provided for @errorWrongCodeGeneric.
  ///
  /// In ru, this message translates to:
  /// **'Неверный код'**
  String get errorWrongCodeGeneric;

  /// No description provided for @errorWrongPassword.
  ///
  /// In ru, this message translates to:
  /// **'Неверный пароль: {details}'**
  String errorWrongPassword(String details);

  /// No description provided for @errorWrongPasswordGeneric.
  ///
  /// In ru, this message translates to:
  /// **'Неверный пароль'**
  String get errorWrongPasswordGeneric;

  /// No description provided for @errorRegistrationFailed.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка регистрации: {details}'**
  String errorRegistrationFailed(String details);

  /// No description provided for @errorRegistrationFailedGeneric.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка регистрации'**
  String get errorRegistrationFailedGeneric;

  /// No description provided for @errorChannelSearchFailed.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка поиска каналов: {details}'**
  String errorChannelSearchFailed(String details);

  /// No description provided for @errorChannelSearchFailedGeneric.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка поиска каналов'**
  String get errorChannelSearchFailedGeneric;

  /// No description provided for @errorChannelConnectFailed.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка подключения к каналам: {details}'**
  String errorChannelConnectFailed(String details);

  /// No description provided for @errorChannelConnectFailedGeneric.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка подключения к каналам'**
  String get errorChannelConnectFailedGeneric;

  /// No description provided for @errorChannelCreateFailed.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка создания каналов: {details}'**
  String errorChannelCreateFailed(String details);

  /// No description provided for @errorChannelCreateFailedGeneric.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка создания каналов'**
  String get errorChannelCreateFailedGeneric;

  /// No description provided for @errorFillClientData.
  ///
  /// In ru, this message translates to:
  /// **'Заполните данные клиента'**
  String get errorFillClientData;

  /// No description provided for @shiftCashInvestments.
  ///
  /// In ru, this message translates to:
  /// **'Внесения'**
  String get shiftCashInvestments;

  /// No description provided for @shiftCashExpenses.
  ///
  /// In ru, this message translates to:
  /// **'Расходы'**
  String get shiftCashExpenses;

  /// No description provided for @shiftCashDividends.
  ///
  /// In ru, this message translates to:
  /// **'Изъятия'**
  String get shiftCashDividends;

  /// No description provided for @shiftNoCashOps.
  ///
  /// In ru, this message translates to:
  /// **'Нет кассовых операций'**
  String get shiftNoCashOps;

  /// No description provided for @shiftNoCashOpsDescription.
  ///
  /// In ru, this message translates to:
  /// **'Внесения, расходы и изъятия\nбудут отображаться здесь'**
  String get shiftNoCashOpsDescription;

  /// No description provided for @shiftMoreItems.
  ///
  /// In ru, this message translates to:
  /// **'+{count} ещё'**
  String shiftMoreItems(int count);

  /// No description provided for @shiftEqualsSystem.
  ///
  /// In ru, this message translates to:
  /// **'= Система'**
  String get shiftEqualsSystem;

  /// No description provided for @shiftBillsTotal.
  ///
  /// In ru, this message translates to:
  /// **'Итого по купюрам:'**
  String get shiftBillsTotal;

  /// No description provided for @receiptInputTitle.
  ///
  /// In ru, this message translates to:
  /// **'Поиск чека'**
  String get receiptInputTitle;

  /// No description provided for @receiptInputNumber.
  ///
  /// In ru, this message translates to:
  /// **'Номер чека'**
  String get receiptInputNumber;

  /// No description provided for @receiptInputNumberHint.
  ///
  /// In ru, this message translates to:
  /// **'Например: 12345'**
  String get receiptInputNumberHint;

  /// No description provided for @receiptInputPos.
  ///
  /// In ru, this message translates to:
  /// **'Касса'**
  String get receiptInputPos;

  /// No description provided for @receiptInputInvalid.
  ///
  /// In ru, this message translates to:
  /// **'Введите корректный номер чека'**
  String get receiptInputInvalid;

  /// No description provided for @receiptInputFind.
  ///
  /// In ru, this message translates to:
  /// **'Найти'**
  String get receiptInputFind;

  /// No description provided for @paymentDenominations.
  ///
  /// In ru, this message translates to:
  /// **'Номиналы'**
  String get paymentDenominations;

  /// No description provided for @paymentExactAmount.
  ///
  /// In ru, this message translates to:
  /// **'Без сдачи'**
  String get paymentExactAmount;

  /// No description provided for @paymentNumpad.
  ///
  /// In ru, this message translates to:
  /// **'Клавиатура'**
  String get paymentNumpad;

  /// No description provided for @paymentIinLabel.
  ///
  /// In ru, this message translates to:
  /// **'ИИН/БИН (необязательно)'**
  String get paymentIinLabel;

  /// No description provided for @paymentIinInvalid.
  ///
  /// In ru, this message translates to:
  /// **'Некорректный ИИН/БИН'**
  String get paymentIinInvalid;

  /// No description provided for @paymentIinHint.
  ///
  /// In ru, this message translates to:
  /// **'ИИН — для физических лиц, БИН — для юридических'**
  String get paymentIinHint;

  /// No description provided for @paymentIinShort.
  ///
  /// In ru, this message translates to:
  /// **'ИИН/БИН'**
  String get paymentIinShort;

  /// No description provided for @paymentTypeCash.
  ///
  /// In ru, this message translates to:
  /// **'Наличная'**
  String get paymentTypeCash;

  /// No description provided for @paymentTypeCard.
  ///
  /// In ru, this message translates to:
  /// **'Безналичная'**
  String get paymentTypeCard;

  /// No description provided for @paymentTypeMixed.
  ///
  /// In ru, this message translates to:
  /// **'Смешанная'**
  String get paymentTypeMixed;

  /// No description provided for @paymentAccount.
  ///
  /// In ru, this message translates to:
  /// **'Счёт'**
  String get paymentAccount;

  /// No description provided for @authNoUsers.
  ///
  /// In ru, this message translates to:
  /// **'Нет зарегистрированных пользователей'**
  String get authNoUsers;

  /// No description provided for @authNoPin.
  ///
  /// In ru, this message translates to:
  /// **'Без PIN'**
  String get authNoPin;

  /// No description provided for @authSelectUser.
  ///
  /// In ru, this message translates to:
  /// **'Выберите пользователя'**
  String get authSelectUser;

  /// No description provided for @authNoUsersShort.
  ///
  /// In ru, this message translates to:
  /// **'Нет пользователей'**
  String get authNoUsersShort;

  /// No description provided for @authEnterPin.
  ///
  /// In ru, this message translates to:
  /// **'Введите PIN-код'**
  String get authEnterPin;

  /// No description provided for @updateVersion.
  ///
  /// In ru, this message translates to:
  /// **'Версия {version}'**
  String updateVersion(String version);

  /// No description provided for @updateWhatsNew.
  ///
  /// In ru, this message translates to:
  /// **'Что нового'**
  String get updateWhatsNew;

  /// No description provided for @updateFixedIssues.
  ///
  /// In ru, this message translates to:
  /// **'Исправлено'**
  String get updateFixedIssues;

  /// No description provided for @updateSize.
  ///
  /// In ru, this message translates to:
  /// **'Размер'**
  String get updateSize;

  /// No description provided for @updateDate.
  ///
  /// In ru, this message translates to:
  /// **'Дата'**
  String get updateDate;

  /// No description provided for @updateMandatory.
  ///
  /// In ru, this message translates to:
  /// **'Это обязательное обновление'**
  String get updateMandatory;

  /// No description provided for @updateLaterCountdown.
  ///
  /// In ru, this message translates to:
  /// **'Позже ({countdown})'**
  String updateLaterCountdown(int countdown);

  /// No description provided for @updateDownloading.
  ///
  /// In ru, this message translates to:
  /// **'Загрузка обновления'**
  String get updateDownloading;

  /// No description provided for @updateDownloadingFile.
  ///
  /// In ru, this message translates to:
  /// **'Загрузка файла обновления...'**
  String get updateDownloadingFile;

  /// No description provided for @updatePosNow.
  ///
  /// In ru, this message translates to:
  /// **'ОБНОВИТЬ КАССУ'**
  String get updatePosNow;

  /// No description provided for @serviceAddNote.
  ///
  /// In ru, this message translates to:
  /// **'Добавить отметку'**
  String get serviceAddNote;

  /// No description provided for @serviceClientLookup.
  ///
  /// In ru, this message translates to:
  /// **'Поиск клиента'**
  String get serviceClientLookup;

  /// No description provided for @serviceOrderDetail.
  ///
  /// In ru, this message translates to:
  /// **'Детали заказ-наряда #{orderId}'**
  String serviceOrderDetail(int orderId);

  /// No description provided for @paymentDefaultLabel.
  ///
  /// In ru, this message translates to:
  /// **'По умолчанию'**
  String get paymentDefaultLabel;

  /// No description provided for @serviceIntakeTitle.
  ///
  /// In ru, this message translates to:
  /// **'Приём заказа'**
  String get serviceIntakeTitle;

  /// No description provided for @serviceIntakeClient.
  ///
  /// In ru, this message translates to:
  /// **'Клиент'**
  String get serviceIntakeClient;

  /// No description provided for @serviceIntakeDevice.
  ///
  /// In ru, this message translates to:
  /// **'Устройство / Предмет'**
  String get serviceIntakeDevice;

  /// No description provided for @serviceIntakeServices.
  ///
  /// In ru, this message translates to:
  /// **'Услуги'**
  String get serviceIntakeServices;

  /// No description provided for @serviceIntakeDelivery.
  ///
  /// In ru, this message translates to:
  /// **'Доставка'**
  String get serviceIntakeDelivery;

  /// No description provided for @serviceIntakePickup.
  ///
  /// In ru, this message translates to:
  /// **'Забрать у клиента'**
  String get serviceIntakePickup;

  /// No description provided for @serviceIntakeSave.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить'**
  String get serviceIntakeSave;

  /// No description provided for @serviceIntakeCancel.
  ///
  /// In ru, this message translates to:
  /// **'Отмена'**
  String get serviceIntakeCancel;

  /// No description provided for @serviceQueueTitle.
  ///
  /// In ru, this message translates to:
  /// **'Заказ-наряды'**
  String get serviceQueueTitle;

  /// No description provided for @serviceQueueEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Нет заказ-нарядов'**
  String get serviceQueueEmpty;

  /// No description provided for @serviceQueueSearch.
  ///
  /// In ru, this message translates to:
  /// **'Поиск по номеру, клиенту, устройству'**
  String get serviceQueueSearch;

  /// No description provided for @serviceDetailTitle.
  ///
  /// In ru, this message translates to:
  /// **'Детали заказа'**
  String get serviceDetailTitle;

  /// No description provided for @serviceDetailInfo.
  ///
  /// In ru, this message translates to:
  /// **'Информация'**
  String get serviceDetailInfo;

  /// No description provided for @serviceDetailTimeline.
  ///
  /// In ru, this message translates to:
  /// **'Работы'**
  String get serviceDetailTimeline;

  /// No description provided for @serviceDetailCost.
  ///
  /// In ru, this message translates to:
  /// **'Стоимость'**
  String get serviceDetailCost;

  /// No description provided for @serviceDetailActions.
  ///
  /// In ru, this message translates to:
  /// **'Действия'**
  String get serviceDetailActions;

  /// No description provided for @serviceStatusIntake.
  ///
  /// In ru, this message translates to:
  /// **'Приём'**
  String get serviceStatusIntake;

  /// No description provided for @serviceStatusInProgress.
  ///
  /// In ru, this message translates to:
  /// **'В работе'**
  String get serviceStatusInProgress;

  /// No description provided for @serviceStatusCompleted.
  ///
  /// In ru, this message translates to:
  /// **'Готов'**
  String get serviceStatusCompleted;

  /// No description provided for @serviceStatusClosed.
  ///
  /// In ru, this message translates to:
  /// **'Закрыт'**
  String get serviceStatusClosed;

  /// No description provided for @serviceStatusCancelled.
  ///
  /// In ru, this message translates to:
  /// **'Отменён'**
  String get serviceStatusCancelled;

  /// No description provided for @serviceMarkDiagnostic.
  ///
  /// In ru, this message translates to:
  /// **'Диагностика'**
  String get serviceMarkDiagnostic;

  /// No description provided for @serviceMarkReplacement.
  ///
  /// In ru, this message translates to:
  /// **'Замена детали'**
  String get serviceMarkReplacement;

  /// No description provided for @serviceMarkRepair.
  ///
  /// In ru, this message translates to:
  /// **'Ремонт'**
  String get serviceMarkRepair;

  /// No description provided for @serviceMarkTesting.
  ///
  /// In ru, this message translates to:
  /// **'Тестирование'**
  String get serviceMarkTesting;

  /// No description provided for @serviceMarkOther.
  ///
  /// In ru, this message translates to:
  /// **'Прочее'**
  String get serviceMarkOther;

  /// No description provided for @serviceAddMark.
  ///
  /// In ru, this message translates to:
  /// **'Добавить работу'**
  String get serviceAddMark;

  /// No description provided for @serviceDeleteMark.
  ///
  /// In ru, this message translates to:
  /// **'Удалить отметку'**
  String get serviceDeleteMark;

  /// No description provided for @serviceMarkDescription.
  ///
  /// In ru, this message translates to:
  /// **'Описание'**
  String get serviceMarkDescription;

  /// No description provided for @serviceMarkType.
  ///
  /// In ru, this message translates to:
  /// **'Тип работы'**
  String get serviceMarkType;

  /// No description provided for @serviceMarkCost.
  ///
  /// In ru, this message translates to:
  /// **'Стоимость'**
  String get serviceMarkCost;

  /// No description provided for @serviceMarkNote.
  ///
  /// In ru, this message translates to:
  /// **'Примечание'**
  String get serviceMarkNote;

  /// No description provided for @serviceCatalogTitle.
  ///
  /// In ru, this message translates to:
  /// **'Каталог услуг'**
  String get serviceCatalogTitle;

  /// No description provided for @serviceCatalogAdd.
  ///
  /// In ru, this message translates to:
  /// **'Добавить услугу'**
  String get serviceCatalogAdd;

  /// No description provided for @serviceCatalogDuration.
  ///
  /// In ru, this message translates to:
  /// **'мин'**
  String get serviceCatalogDuration;

  /// No description provided for @serviceCatalogWarranty.
  ///
  /// In ru, this message translates to:
  /// **'Гарантия (дней)'**
  String get serviceCatalogWarranty;

  /// No description provided for @serviceCatalogRequiresDevice.
  ///
  /// In ru, this message translates to:
  /// **'Требуется устройство'**
  String get serviceCatalogRequiresDevice;

  /// No description provided for @serviceClientNew.
  ///
  /// In ru, this message translates to:
  /// **'Новый клиент'**
  String get serviceClientNew;

  /// No description provided for @serviceClientPhone.
  ///
  /// In ru, this message translates to:
  /// **'Телефон'**
  String get serviceClientPhone;

  /// No description provided for @serviceClientName.
  ///
  /// In ru, this message translates to:
  /// **'Имя'**
  String get serviceClientName;

  /// No description provided for @serviceClientAddress.
  ///
  /// In ru, this message translates to:
  /// **'Адрес'**
  String get serviceClientAddress;

  /// No description provided for @serviceAssignTechnician.
  ///
  /// In ru, this message translates to:
  /// **'Назначить мастера'**
  String get serviceAssignTechnician;

  /// Tooltip/action to assign or reassign the technician on a service order
  ///
  /// In ru, this message translates to:
  /// **'Переназначить мастера'**
  String get serviceReassignTechnician;

  /// Snackbar shown after assigning a technician
  ///
  /// In ru, this message translates to:
  /// **'Мастер назначен: {name}'**
  String serviceTechnicianAssigned(String name);

  /// No description provided for @serviceTechnicianSelect.
  ///
  /// In ru, this message translates to:
  /// **'Выберите мастера'**
  String get serviceTechnicianSelect;

  /// No description provided for @servicePrepayment.
  ///
  /// In ru, this message translates to:
  /// **'Предоплата'**
  String get servicePrepayment;

  /// No description provided for @servicePrepaymentAmount.
  ///
  /// In ru, this message translates to:
  /// **'Сумма предоплаты'**
  String get servicePrepaymentAmount;

  /// No description provided for @serviceEstimatedDate.
  ///
  /// In ru, this message translates to:
  /// **'Ожидаемая дата'**
  String get serviceEstimatedDate;

  /// No description provided for @serviceEstimatedAmount.
  ///
  /// In ru, this message translates to:
  /// **'Сумма'**
  String get serviceEstimatedAmount;

  /// No description provided for @servicePrintLabel.
  ///
  /// In ru, this message translates to:
  /// **'QR-этикетка'**
  String get servicePrintLabel;

  /// No description provided for @servicePrintReceipt.
  ///
  /// In ru, this message translates to:
  /// **'Печать чека'**
  String get servicePrintReceipt;

  /// No description provided for @serviceProgressConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Начать работу'**
  String get serviceProgressConfirm;

  /// No description provided for @serviceCancelConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Отменить'**
  String get serviceCancelConfirm;

  /// No description provided for @serviceTotalCost.
  ///
  /// In ru, this message translates to:
  /// **'Стоимость работ'**
  String get serviceTotalCost;

  /// No description provided for @servicePrepaid.
  ///
  /// In ru, this message translates to:
  /// **'Предоплата'**
  String get servicePrepaid;

  /// No description provided for @serviceRemaining.
  ///
  /// In ru, this message translates to:
  /// **'К оплате'**
  String get serviceRemaining;

  /// No description provided for @serviceDeliveryAddress.
  ///
  /// In ru, this message translates to:
  /// **'Адрес доставки'**
  String get serviceDeliveryAddress;

  /// No description provided for @serviceNeedsPickup.
  ///
  /// In ru, this message translates to:
  /// **'Забрать у клиента'**
  String get serviceNeedsPickup;

  /// No description provided for @serviceNeedsDelivery.
  ///
  /// In ru, this message translates to:
  /// **'Доставить клиенту'**
  String get serviceNeedsDelivery;

  /// No description provided for @serviceQrFormat.
  ///
  /// In ru, this message translates to:
  /// **'TELEPOS:SO:{id}:{number}'**
  String serviceQrFormat(Object id, Object number);

  /// No description provided for @serviceOrderCreated.
  ///
  /// In ru, this message translates to:
  /// **'Новый заказ'**
  String get serviceOrderCreated;

  /// No description provided for @serviceOrderUpdated.
  ///
  /// In ru, this message translates to:
  /// **'Редактировать'**
  String get serviceOrderUpdated;

  /// No description provided for @serviceNoOrders.
  ///
  /// In ru, this message translates to:
  /// **'Нет данных'**
  String get serviceNoOrders;

  /// No description provided for @serviceFilterAll.
  ///
  /// In ru, this message translates to:
  /// **'Все'**
  String get serviceFilterAll;

  /// No description provided for @navCatalog.
  ///
  /// In ru, this message translates to:
  /// **'Каталог'**
  String get navCatalog;

  /// No description provided for @catalogTitle.
  ///
  /// In ru, this message translates to:
  /// **'Каталог товаров'**
  String get catalogTitle;

  /// No description provided for @catalogSearch.
  ///
  /// In ru, this message translates to:
  /// **'Поиск'**
  String get catalogSearch;

  /// No description provided for @catalogSearchHint.
  ///
  /// In ru, this message translates to:
  /// **'Название или штрихкод'**
  String get catalogSearchHint;

  /// No description provided for @catalogFilterAll.
  ///
  /// In ru, this message translates to:
  /// **'Все'**
  String get catalogFilterAll;

  /// No description provided for @catalogFilterProducts.
  ///
  /// In ru, this message translates to:
  /// **'Товары'**
  String get catalogFilterProducts;

  /// No description provided for @catalogFilterWeighted.
  ///
  /// In ru, this message translates to:
  /// **'Весовые'**
  String get catalogFilterWeighted;

  /// No description provided for @catalogFilterServices.
  ///
  /// In ru, this message translates to:
  /// **'Услуги'**
  String get catalogFilterServices;

  /// No description provided for @catalogFilterPackages.
  ///
  /// In ru, this message translates to:
  /// **'Упаковки'**
  String get catalogFilterPackages;

  /// No description provided for @catalogAddProduct.
  ///
  /// In ru, this message translates to:
  /// **'Добавить товар'**
  String get catalogAddProduct;

  /// No description provided for @catalogEditProduct.
  ///
  /// In ru, this message translates to:
  /// **'Редактировать товар'**
  String get catalogEditProduct;

  /// No description provided for @catalogDeleteProduct.
  ///
  /// In ru, this message translates to:
  /// **'Удалить товар'**
  String get catalogDeleteProduct;

  /// No description provided for @catalogRestoreProduct.
  ///
  /// In ru, this message translates to:
  /// **'Восстановить товар'**
  String get catalogRestoreProduct;

  /// No description provided for @catalogProductName.
  ///
  /// In ru, this message translates to:
  /// **'Название'**
  String get catalogProductName;

  /// No description provided for @catalogBarcode.
  ///
  /// In ru, this message translates to:
  /// **'Штрихкод'**
  String get catalogBarcode;

  /// No description provided for @catalogType.
  ///
  /// In ru, this message translates to:
  /// **'Тип'**
  String get catalogType;

  /// No description provided for @catalogPrice.
  ///
  /// In ru, this message translates to:
  /// **'Цена продажи'**
  String get catalogPrice;

  /// No description provided for @catalogWholesalePrice.
  ///
  /// In ru, this message translates to:
  /// **'Оптовая цена'**
  String get catalogWholesalePrice;

  /// No description provided for @catalogCategory.
  ///
  /// In ru, this message translates to:
  /// **'Категория'**
  String get catalogCategory;

  /// No description provided for @catalogMeasure.
  ///
  /// In ru, this message translates to:
  /// **'Единица измерения'**
  String get catalogMeasure;

  /// No description provided for @catalogQuantity.
  ///
  /// In ru, this message translates to:
  /// **'Остаток'**
  String get catalogQuantity;

  /// No description provided for @catalogQuickProduct.
  ///
  /// In ru, this message translates to:
  /// **'Быстрый товар'**
  String get catalogQuickProduct;

  /// No description provided for @catalogAddToQuick.
  ///
  /// In ru, this message translates to:
  /// **'Добавить в быстрые'**
  String get catalogAddToQuick;

  /// No description provided for @catalogRemoveFromQuick.
  ///
  /// In ru, this message translates to:
  /// **'Убрать из быстрых'**
  String get catalogRemoveFromQuick;

  /// No description provided for @catalogNoProducts.
  ///
  /// In ru, this message translates to:
  /// **'Нет товаров'**
  String get catalogNoProducts;

  /// No description provided for @catalogDeleted.
  ///
  /// In ru, this message translates to:
  /// **'Удалён'**
  String get catalogDeleted;

  /// No description provided for @catalogConfirmDelete.
  ///
  /// In ru, this message translates to:
  /// **'Удалить товар \"{name}\"?'**
  String catalogConfirmDelete(String name);

  /// No description provided for @catalogProductCreated.
  ///
  /// In ru, this message translates to:
  /// **'Товар создан'**
  String get catalogProductCreated;

  /// No description provided for @catalogProductUpdated.
  ///
  /// In ru, this message translates to:
  /// **'Товар обновлён'**
  String get catalogProductUpdated;

  /// No description provided for @catalogProductDeleted.
  ///
  /// In ru, this message translates to:
  /// **'Товар удалён'**
  String get catalogProductDeleted;

  /// No description provided for @catalogProductRestored.
  ///
  /// In ru, this message translates to:
  /// **'Товар восстановлен'**
  String get catalogProductRestored;

  /// No description provided for @catalogShowDeleted.
  ///
  /// In ru, this message translates to:
  /// **'Показать удалённые'**
  String get catalogShowDeleted;

  /// No description provided for @catalogTypeNormal.
  ///
  /// In ru, this message translates to:
  /// **'Обычный'**
  String get catalogTypeNormal;

  /// No description provided for @catalogTypeWeight.
  ///
  /// In ru, this message translates to:
  /// **'Весовой'**
  String get catalogTypeWeight;

  /// No description provided for @catalogTypeInner.
  ///
  /// In ru, this message translates to:
  /// **'Внутренний'**
  String get catalogTypeInner;

  /// No description provided for @catalogTypePackage.
  ///
  /// In ru, this message translates to:
  /// **'Упаковка'**
  String get catalogTypePackage;

  /// No description provided for @catalogTypeService.
  ///
  /// In ru, this message translates to:
  /// **'Услуга'**
  String get catalogTypeService;

  /// No description provided for @catalogMeasurePiece.
  ///
  /// In ru, this message translates to:
  /// **'Штука'**
  String get catalogMeasurePiece;

  /// No description provided for @catalogMeasureKg.
  ///
  /// In ru, this message translates to:
  /// **'Килограмм'**
  String get catalogMeasureKg;

  /// No description provided for @catalogMeasureLiter.
  ///
  /// In ru, this message translates to:
  /// **'Литр'**
  String get catalogMeasureLiter;

  /// No description provided for @catalogMeasureMeter.
  ///
  /// In ru, this message translates to:
  /// **'Метр'**
  String get catalogMeasureMeter;

  /// No description provided for @catalogNameRequired.
  ///
  /// In ru, this message translates to:
  /// **'Введите название'**
  String get catalogNameRequired;

  /// No description provided for @catalogPriceRequired.
  ///
  /// In ru, this message translates to:
  /// **'Введите цену'**
  String get catalogPriceRequired;

  /// No description provided for @catalogPriceInvalid.
  ///
  /// In ru, this message translates to:
  /// **'Цена должна быть больше 0'**
  String get catalogPriceInvalid;

  /// No description provided for @catalogBarcodeExists.
  ///
  /// In ru, this message translates to:
  /// **'Товар с таким штрихкодом уже существует'**
  String get catalogBarcodeExists;

  /// No description provided for @catalogCategories.
  ///
  /// In ru, this message translates to:
  /// **'Категории'**
  String get catalogCategories;

  /// No description provided for @catalogAllCategories.
  ///
  /// In ru, this message translates to:
  /// **'Все категории'**
  String get catalogAllCategories;

  /// No description provided for @catalogNoCategories.
  ///
  /// In ru, this message translates to:
  /// **'Нет категорий'**
  String get catalogNoCategories;

  /// No description provided for @catalogQuickProductCategory.
  ///
  /// In ru, this message translates to:
  /// **'Категория быстрых товаров'**
  String get catalogQuickProductCategory;

  /// No description provided for @catalogAddCategory.
  ///
  /// In ru, this message translates to:
  /// **'Добавить категорию'**
  String get catalogAddCategory;

  /// No description provided for @catalogCategoryName.
  ///
  /// In ru, this message translates to:
  /// **'Название категории'**
  String get catalogCategoryName;

  /// No description provided for @catalogManageCategories.
  ///
  /// In ru, this message translates to:
  /// **'Управление категориями'**
  String get catalogManageCategories;

  /// No description provided for @catalogCategoryHasProducts.
  ///
  /// In ru, this message translates to:
  /// **'Невозможно удалить: в категории есть товары'**
  String get catalogCategoryHasProducts;

  /// No description provided for @catalogConfirmDeleteCategory.
  ///
  /// In ru, this message translates to:
  /// **'Удалить категорию'**
  String get catalogConfirmDeleteCategory;

  /// No description provided for @catalogMenuCategories.
  ///
  /// In ru, this message translates to:
  /// **'Категории меню'**
  String get catalogMenuCategories;

  /// No description provided for @catalogParentCategory.
  ///
  /// In ru, this message translates to:
  /// **'Родительская категория'**
  String get catalogParentCategory;

  /// No description provided for @catalogRootCategory.
  ///
  /// In ru, this message translates to:
  /// **'Корневая (без родителя)'**
  String get catalogRootCategory;

  /// No description provided for @telegramErrorPhoneSendFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось отправить код на телефон'**
  String get telegramErrorPhoneSendFailed;

  /// No description provided for @telegramErrorQrAuthFailed.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка авторизации по QR-коду'**
  String get telegramErrorQrAuthFailed;

  /// No description provided for @telegramErrorWrongCode.
  ///
  /// In ru, this message translates to:
  /// **'Неверный код подтверждения'**
  String get telegramErrorWrongCode;

  /// No description provided for @telegramErrorWrongPassword.
  ///
  /// In ru, this message translates to:
  /// **'Неверный пароль'**
  String get telegramErrorWrongPassword;

  /// No description provided for @telegramErrorRegistrationFailed.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка регистрации'**
  String get telegramErrorRegistrationFailed;

  /// No description provided for @telegramErrorChannelSearchFailed.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка поиска каналов'**
  String get telegramErrorChannelSearchFailed;

  /// No description provided for @telegramErrorChannelConnectFailed.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка подключения к каналам'**
  String get telegramErrorChannelConnectFailed;

  /// No description provided for @telegramErrorChannelCreateFailed.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка создания каналов'**
  String get telegramErrorChannelCreateFailed;

  /// No description provided for @hwSettingsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Оборудование'**
  String get hwSettingsTitle;

  /// No description provided for @hwSettingsSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Сканер, дисплей, терминалы'**
  String get hwSettingsSubtitle;

  /// No description provided for @terminalServiceTitle.
  ///
  /// In ru, this message translates to:
  /// **'Браузерные терминалы'**
  String get terminalServiceTitle;

  /// No description provided for @terminalServiceSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Планшет или телефон как рабочее место'**
  String get terminalServiceSubtitle;

  /// No description provided for @terminalServiceEnable.
  ///
  /// In ru, this message translates to:
  /// **'Обслуживать браузерные терминалы'**
  String get terminalServiceEnable;

  /// No description provided for @terminalServiceEnabledNote.
  ///
  /// In ru, this message translates to:
  /// **'Касса слушает сеть магазина. Терминалы могут подключиться.'**
  String get terminalServiceEnabledNote;

  /// No description provided for @terminalServiceDisabledNote.
  ///
  /// In ru, this message translates to:
  /// **'Касса слушает только саму себя. Порт в сеть не открыт, терминалы подключиться не могут.'**
  String get terminalServiceDisabledNote;

  /// No description provided for @terminalServiceRestartNote.
  ///
  /// In ru, this message translates to:
  /// **'Изменение вступит в силу после перезапуска кассы.'**
  String get terminalServiceRestartNote;

  /// No description provided for @terminalServiceAddress.
  ///
  /// In ru, this message translates to:
  /// **'Адрес для терминала'**
  String get terminalServiceAddress;

  /// No description provided for @terminalServiceAddressHint.
  ///
  /// In ru, this message translates to:
  /// **'Откройте этот адрес в браузере планшета. Если имя не открывается, наберите IP-адрес кассы.'**
  String get terminalServiceAddressHint;

  /// No description provided for @pairingTitle.
  ///
  /// In ru, this message translates to:
  /// **'Привязка терминала'**
  String get pairingTitle;

  /// No description provided for @pairingSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Код для нового устройства'**
  String get pairingSubtitle;

  /// No description provided for @pairingDisabledNote.
  ///
  /// In ru, this message translates to:
  /// **'Касса не обслуживает браузерные терминалы. Включите обслуживание, чтобы выдать код привязки.'**
  String get pairingDisabledNote;

  /// No description provided for @pairingDisabledAction.
  ///
  /// In ru, this message translates to:
  /// **'Открыть настройки терминалов'**
  String get pairingDisabledAction;

  /// No description provided for @pairingAddressLabel.
  ///
  /// In ru, this message translates to:
  /// **'Ссылка для нового устройства'**
  String get pairingAddressLabel;

  /// No description provided for @pairingAddressHint.
  ///
  /// In ru, this message translates to:
  /// **'Наберите или скопируйте этот адрес целиком на новом устройстве — код уже в нём.'**
  String get pairingAddressHint;

  /// No description provided for @pairingLinkPending.
  ///
  /// In ru, this message translates to:
  /// **'Ссылка появится здесь после того, как вы выдадите код.'**
  String get pairingLinkPending;

  /// No description provided for @pairingRestartNote.
  ///
  /// In ru, this message translates to:
  /// **'Обслуживание терминалов включено в настройках, но эта касса ещё не перезапущена с ним — адрес пока не откликнется. Перезапустите кассу.'**
  String get pairingRestartNote;

  /// No description provided for @pairingMint.
  ///
  /// In ru, this message translates to:
  /// **'Выдать код'**
  String get pairingMint;

  /// No description provided for @pairingMintAgain.
  ///
  /// In ru, this message translates to:
  /// **'Выдать новый код'**
  String get pairingMintAgain;

  /// No description provided for @pairingCodeLabel.
  ///
  /// In ru, this message translates to:
  /// **'Код привязки'**
  String get pairingCodeLabel;

  /// No description provided for @pairingExpiresAt.
  ///
  /// In ru, this message translates to:
  /// **'Действует до {time}'**
  String pairingExpiresAt(String time);

  /// No description provided for @pairingOnceNote.
  ///
  /// In ru, this message translates to:
  /// **'Код показывается только сейчас — уйдя с этого экрана, вы не увидите его снова. «Выдать новый код» отзывает этот код, если он ещё не использован. Этот код расходуется при открытии ссылки — сам вход на устройстве после этого попросит отдельный второй код: выдайте новый, когда до этого дойдёт дело.'**
  String get pairingOnceNote;

  /// No description provided for @enrolTitle.
  ///
  /// In ru, this message translates to:
  /// **'Привязка терминала'**
  String get enrolTitle;

  /// No description provided for @enrolInstructions.
  ///
  /// In ru, this message translates to:
  /// **'Это устройство ещё не привязано к кассе. Попросите оператора открыть на кассе экран «Привязка терминала» и введите показанный там код.'**
  String get enrolInstructions;

  /// No description provided for @enrolCodeLabel.
  ///
  /// In ru, this message translates to:
  /// **'Код привязки'**
  String get enrolCodeLabel;

  /// No description provided for @enrolSubmit.
  ///
  /// In ru, this message translates to:
  /// **'Привязать'**
  String get enrolSubmit;

  /// No description provided for @accountsSettingsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Счета оплаты'**
  String get accountsSettingsTitle;

  /// No description provided for @accountsSettingsSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Наличные и карточные счета'**
  String get accountsSettingsSubtitle;

  /// No description provided for @accountsSettingsAdd.
  ///
  /// In ru, this message translates to:
  /// **'Добавить счёт'**
  String get accountsSettingsAdd;

  /// No description provided for @accountsSettingsEdit.
  ///
  /// In ru, this message translates to:
  /// **'Редактировать счёт'**
  String get accountsSettingsEdit;

  /// No description provided for @accountsSettingsEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Нет настроенных счетов оплаты'**
  String get accountsSettingsEmpty;

  /// No description provided for @accountsSettingsName.
  ///
  /// In ru, this message translates to:
  /// **'Название счёта'**
  String get accountsSettingsName;

  /// No description provided for @accountsSettingsType.
  ///
  /// In ru, this message translates to:
  /// **'Тип счёта'**
  String get accountsSettingsType;

  /// No description provided for @accountsSettingsTypePOS.
  ///
  /// In ru, this message translates to:
  /// **'Касса (наличные)'**
  String get accountsSettingsTypePOS;

  /// No description provided for @accountsSettingsTypeBank.
  ///
  /// In ru, this message translates to:
  /// **'Банк (карта)'**
  String get accountsSettingsTypeBank;

  /// No description provided for @accountsSettingsTypeCash.
  ///
  /// In ru, this message translates to:
  /// **'Наличные'**
  String get accountsSettingsTypeCash;

  /// No description provided for @accountsSettingsTypeSystem.
  ///
  /// In ru, this message translates to:
  /// **'Системный'**
  String get accountsSettingsTypeSystem;

  /// No description provided for @accountsSettingsTypeBonus.
  ///
  /// In ru, this message translates to:
  /// **'Бонусный'**
  String get accountsSettingsTypeBonus;

  /// No description provided for @accountsSettingsTypeOther.
  ///
  /// In ru, this message translates to:
  /// **'Прочий'**
  String get accountsSettingsTypeOther;

  /// No description provided for @accountsSettingsBalance.
  ///
  /// In ru, this message translates to:
  /// **'Баланс'**
  String get accountsSettingsBalance;

  /// No description provided for @accountsSettingsVisible.
  ///
  /// In ru, this message translates to:
  /// **'POS'**
  String get accountsSettingsVisible;

  /// No description provided for @accountsSettingsVisibleToPos.
  ///
  /// In ru, this message translates to:
  /// **'Видим в POS'**
  String get accountsSettingsVisibleToPos;

  /// No description provided for @hwSettingsSaved.
  ///
  /// In ru, this message translates to:
  /// **'Настройки оборудования сохранены'**
  String get hwSettingsSaved;

  /// No description provided for @hwScannerTitle.
  ///
  /// In ru, this message translates to:
  /// **'Сканер штрих-кодов'**
  String get hwScannerTitle;

  /// No description provided for @hwScannerMode.
  ///
  /// In ru, this message translates to:
  /// **'Режим сканера'**
  String get hwScannerMode;

  /// No description provided for @hwScannerModeKeyboard.
  ///
  /// In ru, this message translates to:
  /// **'USB / клавиатура (wedge)'**
  String get hwScannerModeKeyboard;

  /// No description provided for @hwScannerModeSerial.
  ///
  /// In ru, this message translates to:
  /// **'Серийный'**
  String get hwScannerModeSerial;

  /// No description provided for @hwScannerModeCamera.
  ///
  /// In ru, this message translates to:
  /// **'Камера'**
  String get hwScannerModeCamera;

  /// No description provided for @hwScannerModeHint.
  ///
  /// In ru, this message translates to:
  /// **'USB-сканеры работают в этом режиме'**
  String get hwScannerModeHint;

  /// No description provided for @hwScannerTimeout.
  ///
  /// In ru, this message translates to:
  /// **'Таймаут'**
  String get hwScannerTimeout;

  /// No description provided for @hwScannerMinLength.
  ///
  /// In ru, this message translates to:
  /// **'Мин. длина'**
  String get hwScannerMinLength;

  /// No description provided for @hwScannerMaxLength.
  ///
  /// In ru, this message translates to:
  /// **'Макс. длина'**
  String get hwScannerMaxLength;

  /// No description provided for @hwDisplayTitle.
  ///
  /// In ru, this message translates to:
  /// **'Дисплей покупателя'**
  String get hwDisplayTitle;

  /// No description provided for @hwDisplayModel.
  ///
  /// In ru, this message translates to:
  /// **'Модель'**
  String get hwDisplayModel;

  /// No description provided for @hwDisplayModelLed8.
  ///
  /// In ru, this message translates to:
  /// **'LED 8 символов'**
  String get hwDisplayModelLed8;

  /// No description provided for @hwDisplayModelVfd20.
  ///
  /// In ru, this message translates to:
  /// **'VFD 20x2'**
  String get hwDisplayModelVfd20;

  /// No description provided for @hwDisplayPort.
  ///
  /// In ru, this message translates to:
  /// **'COM-порт'**
  String get hwDisplayPort;

  /// No description provided for @hwDisplayBaudRate.
  ///
  /// In ru, this message translates to:
  /// **'Скорость'**
  String get hwDisplayBaudRate;

  /// No description provided for @hwDisplayDisabled.
  ///
  /// In ru, this message translates to:
  /// **'Дисплей покупателя отключён'**
  String get hwDisplayDisabled;

  /// No description provided for @hwDrawerTitle.
  ///
  /// In ru, this message translates to:
  /// **'Кассовый ящик'**
  String get hwDrawerTitle;

  /// No description provided for @hwDrawerMode.
  ///
  /// In ru, this message translates to:
  /// **'Режим открытия'**
  String get hwDrawerMode;

  /// No description provided for @hwDrawerModePrinter.
  ///
  /// In ru, this message translates to:
  /// **'Через принтер'**
  String get hwDrawerModePrinter;

  /// No description provided for @hwDrawerModeSerial.
  ///
  /// In ru, this message translates to:
  /// **'Серийный порт'**
  String get hwDrawerModeSerial;

  /// No description provided for @hwDrawerPort.
  ///
  /// In ru, this message translates to:
  /// **'COM-порт'**
  String get hwDrawerPort;

  /// No description provided for @hwTerminalsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Платёжные терминалы'**
  String get hwTerminalsTitle;

  /// No description provided for @hwTerminalIp.
  ///
  /// In ru, this message translates to:
  /// **'IP-адрес'**
  String get hwTerminalIp;

  /// No description provided for @hwTerminalPort.
  ///
  /// In ru, this message translates to:
  /// **'Порт'**
  String get hwTerminalPort;

  /// No description provided for @hwTerminalMerchantId.
  ///
  /// In ru, this message translates to:
  /// **'Merchant ID'**
  String get hwTerminalMerchantId;

  /// No description provided for @hwTerminalTerminalId.
  ///
  /// In ru, this message translates to:
  /// **'Terminal ID'**
  String get hwTerminalTerminalId;

  /// No description provided for @catalogExportCsv.
  ///
  /// In ru, this message translates to:
  /// **'Экспорт CSV'**
  String get catalogExportCsv;

  /// No description provided for @catalogImport.
  ///
  /// In ru, this message translates to:
  /// **'Импорт'**
  String get catalogImport;

  /// No description provided for @catalogFilterColumn.
  ///
  /// In ru, this message translates to:
  /// **'Фильтр...'**
  String get catalogFilterColumn;

  /// No description provided for @catalogExportSuccess.
  ///
  /// In ru, this message translates to:
  /// **'Экспортировано в {path}'**
  String catalogExportSuccess(String path);

  /// No description provided for @catalogExportFailed.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка экспорта'**
  String get catalogExportFailed;

  /// No description provided for @catalogImportResults.
  ///
  /// In ru, this message translates to:
  /// **'Результаты импорта'**
  String get catalogImportResults;

  /// No description provided for @catalogImportImported.
  ///
  /// In ru, this message translates to:
  /// **'Импортировано: {count}'**
  String catalogImportImported(int count);

  /// No description provided for @catalogImportUpdated.
  ///
  /// In ru, this message translates to:
  /// **'Обновлено: {count}'**
  String catalogImportUpdated(int count);

  /// No description provided for @catalogImportSkipped.
  ///
  /// In ru, this message translates to:
  /// **'Пропущено: {count}'**
  String catalogImportSkipped(int count);

  /// No description provided for @catalogImportErrors.
  ///
  /// In ru, this message translates to:
  /// **'Ошибки:'**
  String get catalogImportErrors;

  /// No description provided for @catalogTypeConsumable.
  ///
  /// In ru, this message translates to:
  /// **'Расходник'**
  String get catalogTypeConsumable;

  /// No description provided for @catalogFilterConsumable.
  ///
  /// In ru, this message translates to:
  /// **'Расходники'**
  String get catalogFilterConsumable;

  /// No description provided for @catalogFilterInner.
  ///
  /// In ru, this message translates to:
  /// **'Внутренние'**
  String get catalogFilterInner;

  /// No description provided for @serviceMarkConsumable.
  ///
  /// In ru, this message translates to:
  /// **'Расходный материал'**
  String get serviceMarkConsumable;

  /// No description provided for @serviceConsumableSearch.
  ///
  /// In ru, this message translates to:
  /// **'Поиск товара / расходника'**
  String get serviceConsumableSearch;

  /// No description provided for @serviceConsumableSelected.
  ///
  /// In ru, this message translates to:
  /// **'Выбранный товар'**
  String get serviceConsumableSelected;

  /// No description provided for @serviceQuickServicesTitle.
  ///
  /// In ru, this message translates to:
  /// **'Быстрые услуги'**
  String get serviceQuickServicesTitle;

  /// No description provided for @serviceQuickServicesEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Нет быстрых услуг'**
  String get serviceQuickServicesEmpty;

  /// No description provided for @serviceIntakeItems.
  ///
  /// In ru, this message translates to:
  /// **'Принимаемые предметы'**
  String get serviceIntakeItems;

  /// No description provided for @serviceItemName.
  ///
  /// In ru, this message translates to:
  /// **'Что принимаете (предмет, вещь, устройство)'**
  String get serviceItemName;

  /// No description provided for @serviceItemDescription.
  ///
  /// In ru, this message translates to:
  /// **'Описание проблемы / пожелания клиента'**
  String get serviceItemDescription;

  /// No description provided for @serviceItemSerial.
  ///
  /// In ru, this message translates to:
  /// **'Серийный номер / маркировка'**
  String get serviceItemSerial;

  /// No description provided for @serviceItemAdd.
  ///
  /// In ru, this message translates to:
  /// **'Добавить предмет'**
  String get serviceItemAdd;

  /// No description provided for @serviceItemEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Добавьте хотя бы один предмет'**
  String get serviceItemEmpty;

  /// No description provided for @serviceItemCount.
  ///
  /// In ru, this message translates to:
  /// **'{count} шт.'**
  String serviceItemCount(int count);

  /// No description provided for @serviceClientQuickName.
  ///
  /// In ru, this message translates to:
  /// **'Имя клиента'**
  String get serviceClientQuickName;

  /// No description provided for @serviceClientQuickPhone.
  ///
  /// In ru, this message translates to:
  /// **'Телефон клиента'**
  String get serviceClientQuickPhone;

  /// No description provided for @serviceClientOrSearch.
  ///
  /// In ru, this message translates to:
  /// **'или найти в базе'**
  String get serviceClientOrSearch;

  /// No description provided for @catalogTypeDish.
  ///
  /// In ru, this message translates to:
  /// **'Блюдо'**
  String get catalogTypeDish;

  /// No description provided for @catalogFilterDish.
  ///
  /// In ru, this message translates to:
  /// **'Блюда'**
  String get catalogFilterDish;

  /// No description provided for @dishCalculation.
  ///
  /// In ru, this message translates to:
  /// **'Калькуляция'**
  String get dishCalculation;

  /// No description provided for @dishCalculationStub.
  ///
  /// In ru, this message translates to:
  /// **'Модуль калькуляции будет доступен позже'**
  String get dishCalculationStub;

  /// No description provided for @dishIngredients.
  ///
  /// In ru, this message translates to:
  /// **'Ингредиенты'**
  String get dishIngredients;

  /// No description provided for @serviceConsumablesTitle.
  ///
  /// In ru, this message translates to:
  /// **'Нормы расхода'**
  String get serviceConsumablesTitle;

  /// No description provided for @serviceConsumablesEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Нет расходных материалов'**
  String get serviceConsumablesEmpty;

  /// No description provided for @serviceConsumablesAdd.
  ///
  /// In ru, this message translates to:
  /// **'Добавить расходник'**
  String get serviceConsumablesAdd;

  /// No description provided for @serviceConsumableQuantity.
  ///
  /// In ru, this message translates to:
  /// **'Кол-во на 1 услугу'**
  String get serviceConsumableQuantity;

  /// No description provided for @serviceConsumablesAutoAdded.
  ///
  /// In ru, this message translates to:
  /// **'Расходники добавлены автоматически'**
  String get serviceConsumablesAutoAdded;

  /// No description provided for @catalogDescription.
  ///
  /// In ru, this message translates to:
  /// **'Описание'**
  String get catalogDescription;

  /// No description provided for @catalogImagePlaceholder.
  ///
  /// In ru, this message translates to:
  /// **'Нажмите для загрузки фото'**
  String get catalogImagePlaceholder;

  /// No description provided for @catalogImageFromGallery.
  ///
  /// In ru, this message translates to:
  /// **'Выбрать из галереи'**
  String get catalogImageFromGallery;

  /// No description provided for @catalogImageFromCamera.
  ///
  /// In ru, this message translates to:
  /// **'Сделать фото'**
  String get catalogImageFromCamera;

  /// No description provided for @catalogImageRemove.
  ///
  /// In ru, this message translates to:
  /// **'Удалить фото'**
  String get catalogImageRemove;

  /// No description provided for @catalogImagePickError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить фото'**
  String get catalogImagePickError;

  /// No description provided for @globalRetry.
  ///
  /// In ru, this message translates to:
  /// **'Повторить'**
  String get globalRetry;

  /// No description provided for @globalRefresh.
  ///
  /// In ru, this message translates to:
  /// **'Обновить'**
  String get globalRefresh;

  /// No description provided for @globalReset.
  ///
  /// In ru, this message translates to:
  /// **'Сбросить'**
  String get globalReset;

  /// No description provided for @globalApply.
  ///
  /// In ru, this message translates to:
  /// **'Применить'**
  String get globalApply;

  /// No description provided for @globalCreate.
  ///
  /// In ru, this message translates to:
  /// **'Создать'**
  String get globalCreate;

  /// No description provided for @stockOpSupply.
  ///
  /// In ru, this message translates to:
  /// **'Приёмка'**
  String get stockOpSupply;

  /// No description provided for @stockOpMovement.
  ///
  /// In ru, this message translates to:
  /// **'Перемещение'**
  String get stockOpMovement;

  /// No description provided for @stockOpSupplierReturn.
  ///
  /// In ru, this message translates to:
  /// **'Возврат поставщику'**
  String get stockOpSupplierReturn;

  /// No description provided for @stockOpMovementShort.
  ///
  /// In ru, this message translates to:
  /// **'Перем.'**
  String get stockOpMovementShort;

  /// No description provided for @stockOpReturnShort.
  ///
  /// In ru, this message translates to:
  /// **'Возврат'**
  String get stockOpReturnShort;

  /// No description provided for @stockRegistryTitle.
  ///
  /// In ru, this message translates to:
  /// **'Складские операции'**
  String get stockRegistryTitle;

  /// No description provided for @stockRegistryAppBarTitle.
  ///
  /// In ru, this message translates to:
  /// **'Склад'**
  String get stockRegistryAppBarTitle;

  /// No description provided for @stockRegistryLoadError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить реестр'**
  String get stockRegistryLoadError;

  /// No description provided for @stockRegistryResetFilters.
  ///
  /// In ru, this message translates to:
  /// **'Сбросить фильтры'**
  String get stockRegistryResetFilters;

  /// No description provided for @stockRegistryFilters.
  ///
  /// In ru, this message translates to:
  /// **'Фильтры'**
  String get stockRegistryFilters;

  /// No description provided for @stockRegistryEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Нет записей'**
  String get stockRegistryEmpty;

  /// No description provided for @stockRegistryEmptyFiltered.
  ///
  /// In ru, this message translates to:
  /// **'Измените параметры фильтра'**
  String get stockRegistryEmptyFiltered;

  /// No description provided for @stockRegistryEmptyCreate.
  ///
  /// In ru, this message translates to:
  /// **'Создайте первую складскую операцию'**
  String get stockRegistryEmptyCreate;

  /// No description provided for @stockRegistryPeriod.
  ///
  /// In ru, this message translates to:
  /// **'Период'**
  String get stockRegistryPeriod;

  /// No description provided for @stockRegistryOperationType.
  ///
  /// In ru, this message translates to:
  /// **'Тип операции'**
  String get stockRegistryOperationType;

  /// No description provided for @stockRegistrySearchHint.
  ///
  /// In ru, this message translates to:
  /// **'Поиск по номеру, контрагенту...'**
  String get stockRegistrySearchHint;

  /// No description provided for @stockRegistryDateFrom.
  ///
  /// In ru, this message translates to:
  /// **'С'**
  String get stockRegistryDateFrom;

  /// No description provided for @stockRegistryDateTo.
  ///
  /// In ru, this message translates to:
  /// **'По'**
  String get stockRegistryDateTo;

  /// No description provided for @stockRegistryColType.
  ///
  /// In ru, this message translates to:
  /// **'Тип'**
  String get stockRegistryColType;

  /// No description provided for @stockRegistryColNumber.
  ///
  /// In ru, this message translates to:
  /// **'Номер'**
  String get stockRegistryColNumber;

  /// No description provided for @stockRegistryColCounterparty.
  ///
  /// In ru, this message translates to:
  /// **'Контрагент / Склад'**
  String get stockRegistryColCounterparty;

  /// No description provided for @stockRegistryColProducts.
  ///
  /// In ru, this message translates to:
  /// **'Товары'**
  String get stockRegistryColProducts;

  /// No description provided for @stockRegistryColStatus.
  ///
  /// In ru, this message translates to:
  /// **'Статус'**
  String get stockRegistryColStatus;

  /// No description provided for @stockSyncDraft.
  ///
  /// In ru, this message translates to:
  /// **'В работе'**
  String get stockSyncDraft;

  /// No description provided for @stockSyncPending.
  ///
  /// In ru, this message translates to:
  /// **'Ожидает'**
  String get stockSyncPending;

  /// No description provided for @stockSyncSending.
  ///
  /// In ru, this message translates to:
  /// **'Отправка'**
  String get stockSyncSending;

  /// No description provided for @stockSyncSynced.
  ///
  /// In ru, this message translates to:
  /// **'Синхр.'**
  String get stockSyncSynced;

  /// No description provided for @stockRegistryDetailType.
  ///
  /// In ru, this message translates to:
  /// **'Тип: {type}'**
  String stockRegistryDetailType(String type);

  /// No description provided for @stockRegistryDetailDate.
  ///
  /// In ru, this message translates to:
  /// **'Дата: {date}'**
  String stockRegistryDetailDate(String date);

  /// No description provided for @stockRegistryDetailCounterparty.
  ///
  /// In ru, this message translates to:
  /// **'Контрагент: {name}'**
  String stockRegistryDetailCounterparty(String name);

  /// No description provided for @stockRegistryDetailAmount.
  ///
  /// In ru, this message translates to:
  /// **'Сумма: {amount}'**
  String stockRegistryDetailAmount(String amount);

  /// No description provided for @stockRegistryDetailProducts.
  ///
  /// In ru, this message translates to:
  /// **'Товаров: {count}'**
  String stockRegistryDetailProducts(int count);

  /// No description provided for @stockRegistryDetailComment.
  ///
  /// In ru, this message translates to:
  /// **'Комментарий: {comment}'**
  String stockRegistryDetailComment(String comment);

  /// No description provided for @stockRegistryProductsShort.
  ///
  /// In ru, this message translates to:
  /// **'{count} тов.'**
  String stockRegistryProductsShort(int count);

  /// No description provided for @stockRegistryPaginationRange.
  ///
  /// In ru, this message translates to:
  /// **'{from}–{to} из {total}'**
  String stockRegistryPaginationRange(int from, int to, int total);

  /// No description provided for @stockCreateSupplyTitle.
  ///
  /// In ru, this message translates to:
  /// **'Новая приёмка'**
  String get stockCreateSupplyTitle;

  /// No description provided for @stockCreateSupplySubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Приёмка товара от поставщика'**
  String get stockCreateSupplySubtitle;

  /// No description provided for @stockCreateMovementSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Перемещение между складами'**
  String get stockCreateMovementSubtitle;

  /// No description provided for @stockCreateReturnSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Возврат товара поставщику'**
  String get stockCreateReturnSubtitle;

  /// No description provided for @stockCreateWriteoffSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Списание товара (бой, порча, просрочка)'**
  String get stockCreateWriteoffSubtitle;

  /// No description provided for @stockCreateInventorySubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Пересчёт фактических остатков'**
  String get stockCreateInventorySubtitle;

  /// No description provided for @serviceQueueActive.
  ///
  /// In ru, this message translates to:
  /// **'Активных'**
  String get serviceQueueActive;

  /// No description provided for @serviceScanQrTitle.
  ///
  /// In ru, this message translates to:
  /// **'Сканировать QR-метку заказа'**
  String get serviceScanQrTitle;

  /// No description provided for @serviceScanQrHint.
  ///
  /// In ru, this message translates to:
  /// **'TELEPOS:SO:... или номер заказа'**
  String get serviceScanQrHint;

  /// No description provided for @serviceIntakePhotos.
  ///
  /// In ru, this message translates to:
  /// **'Фото приёма'**
  String get serviceIntakePhotos;

  /// No description provided for @serviceIntakePhotosHint.
  ///
  /// In ru, this message translates to:
  /// **'Сделайте фото принимаемых предметов'**
  String get serviceIntakePhotosHint;

  /// No description provided for @expenseTypeOther.
  ///
  /// In ru, this message translates to:
  /// **'Другое'**
  String get expenseTypeOther;

  /// No description provided for @expenseTypeSmallPurchases.
  ///
  /// In ru, this message translates to:
  /// **'Закуп мелочей'**
  String get expenseTypeSmallPurchases;

  /// No description provided for @expenseTypeSalary.
  ///
  /// In ru, this message translates to:
  /// **'Зарплата'**
  String get expenseTypeSalary;

  /// No description provided for @expenseTypeUtilities.
  ///
  /// In ru, this message translates to:
  /// **'Коммунальные'**
  String get expenseTypeUtilities;

  /// No description provided for @expenseTypeCollection.
  ///
  /// In ru, this message translates to:
  /// **'Инкассация'**
  String get expenseTypeCollection;

  /// No description provided for @expenseTypeCustom.
  ///
  /// In ru, this message translates to:
  /// **'Кастомный'**
  String get expenseTypeCustom;

  /// No description provided for @networkTitle.
  ///
  /// In ru, this message translates to:
  /// **'Сеть и подключения'**
  String get networkTitle;

  /// No description provided for @networkUnavailableTitle.
  ///
  /// In ru, this message translates to:
  /// **'Доступно только на устройстве TelePOS OS'**
  String get networkUnavailableTitle;

  /// No description provided for @networkUnavailableDesc.
  ///
  /// In ru, this message translates to:
  /// **'Системный демон telepos-sysd не обнаружен. Управление сетью работает только когда POS запущен на приставке TelePOS OS.'**
  String get networkUnavailableDesc;

  /// No description provided for @networkRefresh.
  ///
  /// In ru, this message translates to:
  /// **'Обновить'**
  String get networkRefresh;

  /// No description provided for @networkSearch.
  ///
  /// In ru, this message translates to:
  /// **'Поиск'**
  String get networkSearch;

  /// No description provided for @networkConnect.
  ///
  /// In ru, this message translates to:
  /// **'Подключить'**
  String get networkConnect;

  /// No description provided for @networkDisconnect.
  ///
  /// In ru, this message translates to:
  /// **'Отключить'**
  String get networkDisconnect;

  /// No description provided for @networkConnected.
  ///
  /// In ru, this message translates to:
  /// **'Подключено'**
  String get networkConnected;

  /// No description provided for @networkEthernetTitle.
  ///
  /// In ru, this message translates to:
  /// **'Проводная сеть (Ethernet)'**
  String get networkEthernetTitle;

  /// No description provided for @networkEthernetDesc.
  ///
  /// In ru, this message translates to:
  /// **'Статус кабельного подключения и доступ в интернет.'**
  String get networkEthernetDesc;

  /// No description provided for @networkCableLabel.
  ///
  /// In ru, this message translates to:
  /// **'Кабель'**
  String get networkCableLabel;

  /// No description provided for @networkCableConnected.
  ///
  /// In ru, this message translates to:
  /// **'Подключён'**
  String get networkCableConnected;

  /// No description provided for @networkCableNotConnected.
  ///
  /// In ru, this message translates to:
  /// **'Не подключён'**
  String get networkCableNotConnected;

  /// No description provided for @networkInternetLabel.
  ///
  /// In ru, this message translates to:
  /// **'Интернет'**
  String get networkInternetLabel;

  /// No description provided for @networkInternetAvailable.
  ///
  /// In ru, this message translates to:
  /// **'Есть доступ'**
  String get networkInternetAvailable;

  /// No description provided for @networkInternetUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Нет доступа'**
  String get networkInternetUnavailable;

  /// No description provided for @networkWifiTitle.
  ///
  /// In ru, this message translates to:
  /// **'Wi-Fi'**
  String get networkWifiTitle;

  /// No description provided for @networkWifiDesc.
  ///
  /// In ru, this message translates to:
  /// **'Подключение к беспроводной сети.'**
  String get networkWifiDesc;

  /// No description provided for @networkWifiSearchHint.
  ///
  /// In ru, this message translates to:
  /// **'Нажмите «Поиск», чтобы найти сети.'**
  String get networkWifiSearchHint;

  /// No description provided for @networkBluetoothTitle.
  ///
  /// In ru, this message translates to:
  /// **'Bluetooth'**
  String get networkBluetoothTitle;

  /// No description provided for @networkBluetoothDesc.
  ///
  /// In ru, this message translates to:
  /// **'Сопряжение с принтерами, весами и другими устройствами.'**
  String get networkBluetoothDesc;

  /// No description provided for @networkBluetoothSearchHint.
  ///
  /// In ru, this message translates to:
  /// **'Нажмите «Поиск», чтобы найти устройства.'**
  String get networkBluetoothSearchHint;

  /// No description provided for @networkBluetoothUnavailableInBrowser.
  ///
  /// In ru, this message translates to:
  /// **'Недоступно в браузере — Bluetooth настраивается только на самой кассе.'**
  String get networkBluetoothUnavailableInBrowser;

  /// No description provided for @networkWifiPasswordTitle.
  ///
  /// In ru, this message translates to:
  /// **'Пароль для «{ssid}»'**
  String networkWifiPasswordTitle(String ssid);

  /// No description provided for @networkWifiPasswordLabel.
  ///
  /// In ru, this message translates to:
  /// **'Пароль Wi-Fi'**
  String get networkWifiPasswordLabel;

  /// No description provided for @networkConnectedTo.
  ///
  /// In ru, this message translates to:
  /// **'Подключено к {ssid}'**
  String networkConnectedTo(String ssid);

  /// No description provided for @networkConnectFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось подключиться к {ssid}'**
  String networkConnectFailed(String ssid);

  /// No description provided for @networkPaired.
  ///
  /// In ru, this message translates to:
  /// **'Сопряжено: {device}'**
  String networkPaired(String device);

  /// No description provided for @networkPairFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось выполнить сопряжение'**
  String get networkPairFailed;

  /// No description provided for @networkEthernetConfigure.
  ///
  /// In ru, this message translates to:
  /// **'Настроить'**
  String get networkEthernetConfigure;

  /// No description provided for @networkEthernetConfigTitle.
  ///
  /// In ru, this message translates to:
  /// **'Настройка Ethernet'**
  String get networkEthernetConfigTitle;

  /// No description provided for @networkEthernetInterface.
  ///
  /// In ru, this message translates to:
  /// **'Интерфейс'**
  String get networkEthernetInterface;

  /// No description provided for @networkEthernetCurrentIp.
  ///
  /// In ru, this message translates to:
  /// **'Текущий IP'**
  String get networkEthernetCurrentIp;

  /// No description provided for @networkEthernetMode.
  ///
  /// In ru, this message translates to:
  /// **'Способ получения адреса'**
  String get networkEthernetMode;

  /// No description provided for @networkEthernetModeDhcp.
  ///
  /// In ru, this message translates to:
  /// **'Автоматически (DHCP)'**
  String get networkEthernetModeDhcp;

  /// No description provided for @networkEthernetModeStatic.
  ///
  /// In ru, this message translates to:
  /// **'Вручную (статический)'**
  String get networkEthernetModeStatic;

  /// No description provided for @networkEthernetIpLabel.
  ///
  /// In ru, this message translates to:
  /// **'IP-адрес'**
  String get networkEthernetIpLabel;

  /// No description provided for @networkEthernetPrefixLabel.
  ///
  /// In ru, this message translates to:
  /// **'Префикс (маска)'**
  String get networkEthernetPrefixLabel;

  /// No description provided for @networkEthernetGatewayLabel.
  ///
  /// In ru, this message translates to:
  /// **'Шлюз'**
  String get networkEthernetGatewayLabel;

  /// No description provided for @networkEthernetDnsLabel.
  ///
  /// In ru, this message translates to:
  /// **'DNS-сервер'**
  String get networkEthernetDnsLabel;

  /// No description provided for @networkEthernetApply.
  ///
  /// In ru, this message translates to:
  /// **'Применить'**
  String get networkEthernetApply;

  /// No description provided for @networkEthernetApplied.
  ///
  /// In ru, this message translates to:
  /// **'Настройки сети применены'**
  String get networkEthernetApplied;

  /// No description provided for @networkEthernetApplyFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось применить настройки сети'**
  String get networkEthernetApplyFailed;

  /// No description provided for @networkEthernetNoInterface.
  ///
  /// In ru, this message translates to:
  /// **'Интерфейс Ethernet не определён'**
  String get networkEthernetNoInterface;

  /// No description provided for @networkEthernetInvalidIp.
  ///
  /// In ru, this message translates to:
  /// **'Неверный IP-адрес'**
  String get networkEthernetInvalidIp;

  /// No description provided for @networkEthernetInvalidGateway.
  ///
  /// In ru, this message translates to:
  /// **'Неверный адрес шлюза'**
  String get networkEthernetInvalidGateway;

  /// No description provided for @networkEthernetInvalidDns.
  ///
  /// In ru, this message translates to:
  /// **'Неверный адрес DNS'**
  String get networkEthernetInvalidDns;

  /// No description provided for @networkEthernetInvalidPrefix.
  ///
  /// In ru, this message translates to:
  /// **'Префикс должен быть от 0 до 32'**
  String get networkEthernetInvalidPrefix;

  /// No description provided for @networkEthernetIpRequired.
  ///
  /// In ru, this message translates to:
  /// **'Укажите IP-адрес'**
  String get networkEthernetIpRequired;

  /// No description provided for @networkEthernetOptional.
  ///
  /// In ru, this message translates to:
  /// **'необязательно'**
  String get networkEthernetOptional;

  /// No description provided for @applianceTitle.
  ///
  /// In ru, this message translates to:
  /// **'Система (TelePOS OS)'**
  String get applianceTitle;

  /// No description provided for @applianceHubSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Управление системой, сеть, драйверы'**
  String get applianceHubSubtitle;

  /// No description provided for @applianceUnavailableDesc.
  ///
  /// In ru, this message translates to:
  /// **'Системный демон telepos-sysd не обнаружен. Этот раздел работает только когда POS запущен на приставке TelePOS OS.'**
  String get applianceUnavailableDesc;

  /// No description provided for @applianceNetworkTitle.
  ///
  /// In ru, this message translates to:
  /// **'Сеть и подключения'**
  String get applianceNetworkTitle;

  /// No description provided for @applianceNetworkDesc.
  ///
  /// In ru, this message translates to:
  /// **'Wi-Fi, проводная сеть и Bluetooth. Нужны для входа и синхронизации.'**
  String get applianceNetworkDesc;

  /// No description provided for @applianceNetworkButton.
  ///
  /// In ru, this message translates to:
  /// **'Настроить сеть'**
  String get applianceNetworkButton;

  /// No description provided for @applianceDesktopTitle.
  ///
  /// In ru, this message translates to:
  /// **'Режим рабочего стола'**
  String get applianceDesktopTitle;

  /// No description provided for @applianceDesktopDesc.
  ///
  /// In ru, this message translates to:
  /// **'Полноценный рабочий стол для установки приложений и обслуживания.'**
  String get applianceDesktopDesc;

  /// No description provided for @applianceCurrentMode.
  ///
  /// In ru, this message translates to:
  /// **'Текущий режим: '**
  String get applianceCurrentMode;

  /// No description provided for @applianceOpenDesktop.
  ///
  /// In ru, this message translates to:
  /// **'Открыть рабочий стол'**
  String get applianceOpenDesktop;

  /// No description provided for @applianceDesktopUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Рабочий стол недоступен в этой сборке.'**
  String get applianceDesktopUnavailable;

  /// No description provided for @applianceModeKiosk.
  ///
  /// In ru, this message translates to:
  /// **'Касса (POS)'**
  String get applianceModeKiosk;

  /// No description provided for @applianceModeDesktop.
  ///
  /// In ru, this message translates to:
  /// **'Рабочий стол'**
  String get applianceModeDesktop;

  /// No description provided for @applianceDriversTitle.
  ///
  /// In ru, this message translates to:
  /// **'Драйверы периферии'**
  String get applianceDriversTitle;

  /// No description provided for @applianceDriversDesc.
  ///
  /// In ru, this message translates to:
  /// **'Установка драйверов принтеров, весов и платёжных терминалов из проверенного каталога TelePOS.'**
  String get applianceDriversDesc;

  /// No description provided for @applianceDriversEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Каталог драйверов пуст.'**
  String get applianceDriversEmpty;

  /// No description provided for @applianceDriverInstall.
  ///
  /// In ru, this message translates to:
  /// **'Установить'**
  String get applianceDriverInstall;

  /// No description provided for @applianceDriverRemove.
  ///
  /// In ru, this message translates to:
  /// **'Удалить'**
  String get applianceDriverRemove;

  /// No description provided for @applianceDriverInstalled.
  ///
  /// In ru, this message translates to:
  /// **'Драйвер установлен: {title}'**
  String applianceDriverInstalled(String title);

  /// No description provided for @applianceDriverRemoved.
  ///
  /// In ru, this message translates to:
  /// **'Драйвер удалён: {title}'**
  String applianceDriverRemoved(String title);

  /// No description provided for @applianceError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка: {message}'**
  String applianceError(String message);

  /// No description provided for @navNetwork.
  ///
  /// In ru, this message translates to:
  /// **'Сеть'**
  String get navNetwork;

  /// No description provided for @navCollapseMenu.
  ///
  /// In ru, this message translates to:
  /// **'Свернуть меню'**
  String get navCollapseMenu;

  /// No description provided for @navExpandMenu.
  ///
  /// In ru, this message translates to:
  /// **'Развернуть меню'**
  String get navExpandMenu;

  /// No description provided for @languageSwitcherTooltip.
  ///
  /// In ru, this message translates to:
  /// **'Язык / Language / Тіл'**
  String get languageSwitcherTooltip;

  /// No description provided for @labelPrinterSettingsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Принтер этикеток'**
  String get labelPrinterSettingsTitle;

  /// No description provided for @labelPrinterSettingsSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Ценники и штрих-коды'**
  String get labelPrinterSettingsSubtitle;

  /// No description provided for @labelPrinterLanguage.
  ///
  /// In ru, this message translates to:
  /// **'Язык принтера'**
  String get labelPrinterLanguage;

  /// No description provided for @labelPrinterSize.
  ///
  /// In ru, this message translates to:
  /// **'Размер этикетки'**
  String get labelPrinterSize;

  /// No description provided for @labelPrinterWidthMm.
  ///
  /// In ru, this message translates to:
  /// **'Ширина, мм'**
  String get labelPrinterWidthMm;

  /// No description provided for @labelPrinterHeightMm.
  ///
  /// In ru, this message translates to:
  /// **'Высота, мм'**
  String get labelPrinterHeightMm;

  /// No description provided for @labelPrinterTestSuccess.
  ///
  /// In ru, this message translates to:
  /// **'Этикетка отправлена на печать'**
  String get labelPrinterTestSuccess;

  /// No description provided for @labelPrinterNotConfigured.
  ///
  /// In ru, this message translates to:
  /// **'Принтер этикеток не настроен. Укажите адрес в настройках.'**
  String get labelPrinterNotConfigured;

  /// No description provided for @labelTemplatesTitle.
  ///
  /// In ru, this message translates to:
  /// **'Шаблоны этикеток'**
  String get labelTemplatesTitle;

  /// No description provided for @labelTemplatesManage.
  ///
  /// In ru, this message translates to:
  /// **'Управление шаблонами'**
  String get labelTemplatesManage;

  /// No description provided for @labelTemplatesManageSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Создание и редактирование раскладок'**
  String get labelTemplatesManageSubtitle;

  /// No description provided for @labelTemplatesEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Шаблоны не найдены'**
  String get labelTemplatesEmpty;

  /// No description provided for @labelTemplateNew.
  ///
  /// In ru, this message translates to:
  /// **'Новый шаблон'**
  String get labelTemplateNew;

  /// No description provided for @labelTemplateEdit.
  ///
  /// In ru, this message translates to:
  /// **'Редактирование шаблона'**
  String get labelTemplateEdit;

  /// No description provided for @labelTemplateBuiltIn.
  ///
  /// In ru, this message translates to:
  /// **'Встроенный'**
  String get labelTemplateBuiltIn;

  /// No description provided for @labelMmUnit.
  ///
  /// In ru, this message translates to:
  /// **'мм'**
  String get labelMmUnit;

  /// No description provided for @labelTemplateDeleteTitle.
  ///
  /// In ru, this message translates to:
  /// **'Удалить шаблон'**
  String get labelTemplateDeleteTitle;

  /// No description provided for @labelTemplateDeleteConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Удалить шаблон «{name}»?'**
  String labelTemplateDeleteConfirm(String name);

  /// No description provided for @labelTemplateName.
  ///
  /// In ru, this message translates to:
  /// **'Название шаблона'**
  String get labelTemplateName;

  /// No description provided for @labelTemplateNameRequired.
  ///
  /// In ru, this message translates to:
  /// **'Укажите название шаблона'**
  String get labelTemplateNameRequired;

  /// No description provided for @labelTemplatePreview.
  ///
  /// In ru, this message translates to:
  /// **'Предпросмотр'**
  String get labelTemplatePreview;

  /// No description provided for @labelTemplateFields.
  ///
  /// In ru, this message translates to:
  /// **'Поля'**
  String get labelTemplateFields;

  /// No description provided for @labelTemplateAddField.
  ///
  /// In ru, this message translates to:
  /// **'Добавить поле'**
  String get labelTemplateAddField;

  /// No description provided for @labelTemplateNoFields.
  ///
  /// In ru, this message translates to:
  /// **'Нет полей. Добавьте хотя бы одно поле.'**
  String get labelTemplateNoFields;

  /// No description provided for @labelFieldKind.
  ///
  /// In ru, this message translates to:
  /// **'Тип поля'**
  String get labelFieldKind;

  /// No description provided for @labelFieldText.
  ///
  /// In ru, this message translates to:
  /// **'Текст'**
  String get labelFieldText;

  /// No description provided for @labelFieldFontSize.
  ///
  /// In ru, this message translates to:
  /// **'Шрифт'**
  String get labelFieldFontSize;

  /// No description provided for @labelFieldBold.
  ///
  /// In ru, this message translates to:
  /// **'Жирный'**
  String get labelFieldBold;

  /// No description provided for @labelFieldKindName.
  ///
  /// In ru, this message translates to:
  /// **'Название'**
  String get labelFieldKindName;

  /// No description provided for @labelFieldKindPrice.
  ///
  /// In ru, this message translates to:
  /// **'Цена'**
  String get labelFieldKindPrice;

  /// No description provided for @labelFieldKindBarcode.
  ///
  /// In ru, this message translates to:
  /// **'Штрих-код'**
  String get labelFieldKindBarcode;

  /// No description provided for @labelFieldKindSku.
  ///
  /// In ru, this message translates to:
  /// **'Артикул'**
  String get labelFieldKindSku;

  /// No description provided for @labelFieldKindDate.
  ///
  /// In ru, this message translates to:
  /// **'Дата'**
  String get labelFieldKindDate;

  /// No description provided for @labelFieldKindText.
  ///
  /// In ru, this message translates to:
  /// **'Текст'**
  String get labelFieldKindText;

  /// No description provided for @labelPrintTitle.
  ///
  /// In ru, this message translates to:
  /// **'Печать ценника'**
  String get labelPrintTitle;

  /// No description provided for @labelPrintBulkTitle.
  ///
  /// In ru, this message translates to:
  /// **'Печать ценников ({count})'**
  String labelPrintBulkTitle(int count);

  /// No description provided for @labelPrintChooseTemplate.
  ///
  /// In ru, this message translates to:
  /// **'Выберите шаблон'**
  String get labelPrintChooseTemplate;

  /// No description provided for @labelPrintCopies.
  ///
  /// In ru, this message translates to:
  /// **'Копий'**
  String get labelPrintCopies;

  /// No description provided for @labelPrintAction.
  ///
  /// In ru, this message translates to:
  /// **'Печать'**
  String get labelPrintAction;

  /// No description provided for @labelPrintedCount.
  ///
  /// In ru, this message translates to:
  /// **'Напечатано: {count}'**
  String labelPrintedCount(int count);

  /// No description provided for @catalogPrintLabel.
  ///
  /// In ru, this message translates to:
  /// **'Печать ценника'**
  String get catalogPrintLabel;

  /// No description provided for @receiptTemplatesTitle.
  ///
  /// In ru, this message translates to:
  /// **'Шаблоны чеков'**
  String get receiptTemplatesTitle;

  /// No description provided for @receiptTemplatesSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Оформление чека: логотип, шапка/подвал, БИН, QR, ширина'**
  String get receiptTemplatesSubtitle;

  /// No description provided for @receiptTemplatesEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Шаблоны не найдены'**
  String get receiptTemplatesEmpty;

  /// No description provided for @receiptTemplateNew.
  ///
  /// In ru, this message translates to:
  /// **'Новый шаблон'**
  String get receiptTemplateNew;

  /// No description provided for @receiptTemplateEdit.
  ///
  /// In ru, this message translates to:
  /// **'Редактирование шаблона'**
  String get receiptTemplateEdit;

  /// No description provided for @receiptTemplateBuiltIn.
  ///
  /// In ru, this message translates to:
  /// **'Встроенный'**
  String get receiptTemplateBuiltIn;

  /// No description provided for @receiptTemplateActive.
  ///
  /// In ru, this message translates to:
  /// **'Активный'**
  String get receiptTemplateActive;

  /// No description provided for @receiptTemplateMakeActive.
  ///
  /// In ru, this message translates to:
  /// **'Сделать активным'**
  String get receiptTemplateMakeActive;

  /// No description provided for @receiptTemplateName.
  ///
  /// In ru, this message translates to:
  /// **'Название шаблона'**
  String get receiptTemplateName;

  /// No description provided for @receiptTemplateNameRequired.
  ///
  /// In ru, this message translates to:
  /// **'Укажите название шаблона'**
  String get receiptTemplateNameRequired;

  /// No description provided for @receiptTemplatePreview.
  ///
  /// In ru, this message translates to:
  /// **'Предпросмотр'**
  String get receiptTemplatePreview;

  /// No description provided for @receiptTemplatePaperWidth.
  ///
  /// In ru, this message translates to:
  /// **'Ширина бумаги'**
  String get receiptTemplatePaperWidth;

  /// No description provided for @receiptTemplateContent.
  ///
  /// In ru, this message translates to:
  /// **'Содержимое чека'**
  String get receiptTemplateContent;

  /// No description provided for @receiptTemplateHeaderFooter.
  ///
  /// In ru, this message translates to:
  /// **'Шапка и подвал'**
  String get receiptTemplateHeaderFooter;

  /// No description provided for @receiptTemplateHeaderText.
  ///
  /// In ru, this message translates to:
  /// **'Текст шапки'**
  String get receiptTemplateHeaderText;

  /// No description provided for @receiptTemplateFooterText.
  ///
  /// In ru, this message translates to:
  /// **'Текст подвала'**
  String get receiptTemplateFooterText;

  /// No description provided for @receiptTemplateExtraFooter.
  ///
  /// In ru, this message translates to:
  /// **'Доп. строки подвала'**
  String get receiptTemplateExtraFooter;

  /// No description provided for @receiptTemplateExtraFooterHint.
  ///
  /// In ru, this message translates to:
  /// **'По одной строке на каждую (например, условия возврата)'**
  String get receiptTemplateExtraFooterHint;

  /// No description provided for @receiptTemplateShowBin.
  ///
  /// In ru, this message translates to:
  /// **'Печатать БИН/ИИН'**
  String get receiptTemplateShowBin;

  /// No description provided for @receiptTemplateShowAddress.
  ///
  /// In ru, this message translates to:
  /// **'Печатать адрес'**
  String get receiptTemplateShowAddress;

  /// No description provided for @receiptTemplateShowCashier.
  ///
  /// In ru, this message translates to:
  /// **'Печатать кассу/кассира'**
  String get receiptTemplateShowCashier;

  /// No description provided for @receiptTemplateShowVat.
  ///
  /// In ru, this message translates to:
  /// **'Печатать НДС'**
  String get receiptTemplateShowVat;

  /// No description provided for @receiptTemplateShowQr.
  ///
  /// In ru, this message translates to:
  /// **'Печатать ссылку проверки (QR)'**
  String get receiptTemplateShowQr;

  /// No description provided for @receiptTemplateShowItemNumbers.
  ///
  /// In ru, this message translates to:
  /// **'Нумеровать позиции'**
  String get receiptTemplateShowItemNumbers;

  /// No description provided for @receiptTemplateShowLogo.
  ///
  /// In ru, this message translates to:
  /// **'Печатать логотип'**
  String get receiptTemplateShowLogo;

  /// No description provided for @receiptTemplateTestPrint.
  ///
  /// In ru, this message translates to:
  /// **'Тестовая печать'**
  String get receiptTemplateTestPrint;

  /// No description provided for @receiptTemplateTestPrintOk.
  ///
  /// In ru, this message translates to:
  /// **'Образец чека отправлен на печать'**
  String get receiptTemplateTestPrintOk;

  /// No description provided for @receiptTemplateTestPrintFail.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось напечатать (проверьте принтер)'**
  String get receiptTemplateTestPrintFail;

  /// No description provided for @receiptTemplateDeleteTitle.
  ///
  /// In ru, this message translates to:
  /// **'Удалить шаблон'**
  String get receiptTemplateDeleteTitle;

  /// No description provided for @receiptTemplateHeaderHint.
  ///
  /// In ru, this message translates to:
  /// **'Несколько строк: приветствие, акция, контакты'**
  String get receiptTemplateHeaderHint;

  /// No description provided for @receiptTemplateFooterHint.
  ///
  /// In ru, this message translates to:
  /// **'Несколько строк: благодарность, условия возврата, сайт, соцсети'**
  String get receiptTemplateFooterHint;

  /// No description provided for @receiptTemplateAlignLeft.
  ///
  /// In ru, this message translates to:
  /// **'Слева'**
  String get receiptTemplateAlignLeft;

  /// No description provided for @receiptTemplateAlignCenter.
  ///
  /// In ru, this message translates to:
  /// **'По центру'**
  String get receiptTemplateAlignCenter;

  /// No description provided for @receiptTemplateAlignRight.
  ///
  /// In ru, this message translates to:
  /// **'Справа'**
  String get receiptTemplateAlignRight;

  /// No description provided for @receiptTemplateBold.
  ///
  /// In ru, this message translates to:
  /// **'Жирный'**
  String get receiptTemplateBold;

  /// No description provided for @receiptTemplateDoubleSize.
  ///
  /// In ru, this message translates to:
  /// **'Крупный (двойной размер)'**
  String get receiptTemplateDoubleSize;

  /// No description provided for @receiptTemplatePaperWidthHint.
  ///
  /// In ru, this message translates to:
  /// **'Ширина ленты задаётся в настройках принтера'**
  String get receiptTemplatePaperWidthHint;

  /// No description provided for @receiptTemplateMandatoryNote.
  ///
  /// In ru, this message translates to:
  /// **'Обязательные реквизиты — номер чека, итог, оплаты, НДС, фискальный признак и QR — печатаются всегда, между шапкой и подвалом'**
  String get receiptTemplateMandatoryNote;

  /// No description provided for @receiptTemplateDeleteConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Удалить шаблон «{name}»?'**
  String receiptTemplateDeleteConfirm(String name);

  /// No description provided for @sysmTitle.
  ///
  /// In ru, this message translates to:
  /// **'Управление системой'**
  String get sysmTitle;

  /// No description provided for @sysmHubSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Состояние, обновления, бэкапы, питание'**
  String get sysmHubSubtitle;

  /// No description provided for @sysmOpenPanel.
  ///
  /// In ru, this message translates to:
  /// **'Открыть панель управления'**
  String get sysmOpenPanel;

  /// No description provided for @sysmNoData.
  ///
  /// In ru, this message translates to:
  /// **'Нет данных'**
  String get sysmNoData;

  /// No description provided for @sysmGenericError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось выполнить операцию'**
  String get sysmGenericError;

  /// No description provided for @sysmHealthTitle.
  ///
  /// In ru, this message translates to:
  /// **'Состояние системы'**
  String get sysmHealthTitle;

  /// No description provided for @sysmHealthDesc.
  ///
  /// In ru, this message translates to:
  /// **'Загрузка процессора, память, диск, температура и время работы'**
  String get sysmHealthDesc;

  /// No description provided for @sysmCpu.
  ///
  /// In ru, this message translates to:
  /// **'Процессор'**
  String get sysmCpu;

  /// No description provided for @sysmCores.
  ///
  /// In ru, this message translates to:
  /// **'ядер'**
  String get sysmCores;

  /// No description provided for @sysmRam.
  ///
  /// In ru, this message translates to:
  /// **'Память'**
  String get sysmRam;

  /// No description provided for @sysmMb.
  ///
  /// In ru, this message translates to:
  /// **'МБ'**
  String get sysmMb;

  /// No description provided for @sysmDisk.
  ///
  /// In ru, this message translates to:
  /// **'Диск'**
  String get sysmDisk;

  /// No description provided for @sysmGb.
  ///
  /// In ru, this message translates to:
  /// **'ГБ'**
  String get sysmGb;

  /// No description provided for @sysmGbFree.
  ///
  /// In ru, this message translates to:
  /// **'ГБ свободно'**
  String get sysmGbFree;

  /// No description provided for @sysmTemperature.
  ///
  /// In ru, this message translates to:
  /// **'Температура'**
  String get sysmTemperature;

  /// No description provided for @sysmUptime.
  ///
  /// In ru, this message translates to:
  /// **'Время работы'**
  String get sysmUptime;

  /// No description provided for @sysmDaysShort.
  ///
  /// In ru, this message translates to:
  /// **'д'**
  String get sysmDaysShort;

  /// No description provided for @sysmHoursShort.
  ///
  /// In ru, this message translates to:
  /// **'ч'**
  String get sysmHoursShort;

  /// No description provided for @sysmMinsShort.
  ///
  /// In ru, this message translates to:
  /// **'м'**
  String get sysmMinsShort;

  /// No description provided for @sysmUpdateTitle.
  ///
  /// In ru, this message translates to:
  /// **'Обновление ПО'**
  String get sysmUpdateTitle;

  /// No description provided for @sysmUpdateDesc.
  ///
  /// In ru, this message translates to:
  /// **'Проверка и установка обновлений системы'**
  String get sysmUpdateDesc;

  /// No description provided for @sysmCurrentVersion.
  ///
  /// In ru, this message translates to:
  /// **'Текущая версия'**
  String get sysmCurrentVersion;

  /// No description provided for @sysmLatestVersion.
  ///
  /// In ru, this message translates to:
  /// **'Доступная версия'**
  String get sysmLatestVersion;

  /// No description provided for @sysmUpdateAvailable.
  ///
  /// In ru, this message translates to:
  /// **'Доступно обновление'**
  String get sysmUpdateAvailable;

  /// No description provided for @sysmCheckUpdate.
  ///
  /// In ru, this message translates to:
  /// **'Проверить'**
  String get sysmCheckUpdate;

  /// No description provided for @sysmUpdateNow.
  ///
  /// In ru, this message translates to:
  /// **'Обновить'**
  String get sysmUpdateNow;

  /// No description provided for @sysmUpdateConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Система загрузит и установит обновление. После установки может потребоваться перезагрузка. Продолжить?'**
  String get sysmUpdateConfirm;

  /// No description provided for @sysmUpdateStarted.
  ///
  /// In ru, this message translates to:
  /// **'Обновление запущено'**
  String get sysmUpdateStarted;

  /// No description provided for @sysmUpdateFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось обновить'**
  String get sysmUpdateFailed;

  /// No description provided for @sysmUpdatePhaseDownload.
  ///
  /// In ru, this message translates to:
  /// **'Загрузка обновления…'**
  String get sysmUpdatePhaseDownload;

  /// No description provided for @sysmUpdatePhaseApply.
  ///
  /// In ru, this message translates to:
  /// **'Установка обновления…'**
  String get sysmUpdatePhaseApply;

  /// No description provided for @sysmRollback.
  ///
  /// In ru, this message translates to:
  /// **'Откатить версию'**
  String get sysmRollback;

  /// No description provided for @sysmRollbackConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Откатиться к предыдущей версии системы?'**
  String get sysmRollbackConfirm;

  /// No description provided for @sysmRollbackDone.
  ///
  /// In ru, this message translates to:
  /// **'Откат выполнен'**
  String get sysmRollbackDone;

  /// No description provided for @sysmBackupTitle.
  ///
  /// In ru, this message translates to:
  /// **'Резервные копии'**
  String get sysmBackupTitle;

  /// No description provided for @sysmBackupDesc.
  ///
  /// In ru, this message translates to:
  /// **'Создание, восстановление и перенос копий на USB'**
  String get sysmBackupDesc;

  /// No description provided for @sysmBackupEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Резервных копий нет'**
  String get sysmBackupEmpty;

  /// No description provided for @sysmBackupCreate.
  ///
  /// In ru, this message translates to:
  /// **'Создать копию'**
  String get sysmBackupCreate;

  /// No description provided for @sysmBackupCreated.
  ///
  /// In ru, this message translates to:
  /// **'Резервная копия создана'**
  String get sysmBackupCreated;

  /// No description provided for @sysmBackupRestore.
  ///
  /// In ru, this message translates to:
  /// **'Восстановить'**
  String get sysmBackupRestore;

  /// No description provided for @sysmBackupRestoreConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Восстановить систему из копии «{name}»? Текущие данные будут заменены.'**
  String sysmBackupRestoreConfirm(String name);

  /// No description provided for @sysmBackupRestored.
  ///
  /// In ru, this message translates to:
  /// **'Восстановление запущено'**
  String get sysmBackupRestored;

  /// No description provided for @sysmBackupExport.
  ///
  /// In ru, this message translates to:
  /// **'На USB'**
  String get sysmBackupExport;

  /// No description provided for @sysmBackupExported.
  ///
  /// In ru, this message translates to:
  /// **'Копия экспортирована на USB'**
  String get sysmBackupExported;

  /// No description provided for @sysmBackupImport.
  ///
  /// In ru, this message translates to:
  /// **'Импорт с USB'**
  String get sysmBackupImport;

  /// No description provided for @sysmBackupImported.
  ///
  /// In ru, this message translates to:
  /// **'Копия импортирована с USB'**
  String get sysmBackupImported;

  /// No description provided for @sysmSnapshotTitle.
  ///
  /// In ru, this message translates to:
  /// **'Снапшоты и сброс'**
  String get sysmSnapshotTitle;

  /// No description provided for @sysmSnapshotDesc.
  ///
  /// In ru, this message translates to:
  /// **'Точки восстановления системы и заводской сброс'**
  String get sysmSnapshotDesc;

  /// No description provided for @sysmSnapshotUnsupported.
  ///
  /// In ru, this message translates to:
  /// **'Снапшоты не поддерживаются на этом устройстве'**
  String get sysmSnapshotUnsupported;

  /// No description provided for @sysmSnapshotEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Снапшотов нет'**
  String get sysmSnapshotEmpty;

  /// No description provided for @sysmSnapshotCreate.
  ///
  /// In ru, this message translates to:
  /// **'Создать снапшот'**
  String get sysmSnapshotCreate;

  /// No description provided for @sysmSnapshotCreated.
  ///
  /// In ru, this message translates to:
  /// **'Снапшот создан'**
  String get sysmSnapshotCreated;

  /// No description provided for @sysmSnapshotRollback.
  ///
  /// In ru, this message translates to:
  /// **'Откатить'**
  String get sysmSnapshotRollback;

  /// No description provided for @sysmSnapshotRollbackConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Откатить систему к снапшоту «{name}»?'**
  String sysmSnapshotRollbackConfirm(String name);

  /// No description provided for @sysmSnapshotRolledBack.
  ///
  /// In ru, this message translates to:
  /// **'Откат к снапшоту выполнен'**
  String get sysmSnapshotRolledBack;

  /// No description provided for @sysmSnapshotRebootRequired.
  ///
  /// In ru, this message translates to:
  /// **'Откат выполнен. Требуется перезагрузка.'**
  String get sysmSnapshotRebootRequired;

  /// No description provided for @sysmFactoryReset.
  ///
  /// In ru, this message translates to:
  /// **'Заводской сброс'**
  String get sysmFactoryReset;

  /// No description provided for @sysmFactoryResetWarn.
  ///
  /// In ru, this message translates to:
  /// **'Удалит все данные и настройки, вернёт устройство к заводскому состоянию.'**
  String get sysmFactoryResetWarn;

  /// No description provided for @sysmFactoryResetConfirm1.
  ///
  /// In ru, this message translates to:
  /// **'Заводской сброс удалит ВСЕ данные, настройки и продажи. Это действие необратимо. Продолжить?'**
  String get sysmFactoryResetConfirm1;

  /// No description provided for @sysmFactoryResetConfirm2.
  ///
  /// In ru, this message translates to:
  /// **'Вы уверены? Все данные будут безвозвратно удалены. Подтвердите заводской сброс.'**
  String get sysmFactoryResetConfirm2;

  /// No description provided for @sysmFactoryResetDo.
  ///
  /// In ru, this message translates to:
  /// **'Сбросить'**
  String get sysmFactoryResetDo;

  /// No description provided for @sysmFactoryResetStarted.
  ///
  /// In ru, this message translates to:
  /// **'Заводской сброс запущен'**
  String get sysmFactoryResetStarted;

  /// No description provided for @sysmDisplayTitle.
  ///
  /// In ru, this message translates to:
  /// **'Экран'**
  String get sysmDisplayTitle;

  /// No description provided for @sysmDisplayDesc.
  ///
  /// In ru, this message translates to:
  /// **'Яркость и поворот экрана'**
  String get sysmDisplayDesc;

  /// No description provided for @sysmDisplayUnsupported.
  ///
  /// In ru, this message translates to:
  /// **'На этом устройстве нет управляемого экрана (нет подсветки/backlight). Яркость и поворот регулируются на самом мониторе.'**
  String get sysmDisplayUnsupported;

  /// No description provided for @sysmRotation.
  ///
  /// In ru, this message translates to:
  /// **'Поворот экрана'**
  String get sysmRotation;

  /// No description provided for @sysmRemoteTitle.
  ///
  /// In ru, this message translates to:
  /// **'Удалённая поддержка'**
  String get sysmRemoteTitle;

  /// No description provided for @sysmRemoteDesc.
  ///
  /// In ru, this message translates to:
  /// **'Временный защищённый доступ для службы поддержки'**
  String get sysmRemoteDesc;

  /// No description provided for @sysmRemoteHelp.
  ///
  /// In ru, this message translates to:
  /// **'«Восстановить поддержку» открывает службе поддержки TelePOS временный защищённый канал (SSH) к приставке, чтобы удалённо решить проблему. Доступ автоматически закрывается через 30 минут. Включайте только по просьбе поддержки.'**
  String get sysmRemoteHelp;

  /// No description provided for @sysmRemoteOn.
  ///
  /// In ru, this message translates to:
  /// **'Доступ включён'**
  String get sysmRemoteOn;

  /// No description provided for @sysmRemoteOff.
  ///
  /// In ru, this message translates to:
  /// **'Доступ выключен'**
  String get sysmRemoteOff;

  /// No description provided for @sysmRemoteExpires.
  ///
  /// In ru, this message translates to:
  /// **'Истекает через {minutes} мин'**
  String sysmRemoteExpires(String minutes);

  /// No description provided for @sysmRemoteEnable.
  ///
  /// In ru, this message translates to:
  /// **'Включить на 30 минут'**
  String get sysmRemoteEnable;

  /// No description provided for @sysmRemoteEnabled.
  ///
  /// In ru, this message translates to:
  /// **'Удалённый доступ включён'**
  String get sysmRemoteEnabled;

  /// No description provided for @sysmRemoteDisable.
  ///
  /// In ru, this message translates to:
  /// **'Отключить доступ'**
  String get sysmRemoteDisable;

  /// No description provided for @sysmRemoteDisabled.
  ///
  /// In ru, this message translates to:
  /// **'Удалённый доступ отключён'**
  String get sysmRemoteDisabled;

  /// No description provided for @sysmPowerTitle.
  ///
  /// In ru, this message translates to:
  /// **'Питание'**
  String get sysmPowerTitle;

  /// No description provided for @sysmPowerDesc.
  ///
  /// In ru, this message translates to:
  /// **'Перезагрузка и выключение устройства'**
  String get sysmPowerDesc;

  /// No description provided for @sysmReboot.
  ///
  /// In ru, this message translates to:
  /// **'Перезагрузить'**
  String get sysmReboot;

  /// No description provided for @sysmRebootConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Перезагрузить устройство сейчас?'**
  String get sysmRebootConfirm;

  /// No description provided for @sysmRebooting.
  ///
  /// In ru, this message translates to:
  /// **'Перезагрузка…'**
  String get sysmRebooting;

  /// No description provided for @sysmShutdown.
  ///
  /// In ru, this message translates to:
  /// **'Выключить'**
  String get sysmShutdown;

  /// No description provided for @sysmShutdownConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Выключить устройство сейчас?'**
  String get sysmShutdownConfirm;

  /// No description provided for @sysmShuttingDown.
  ///
  /// In ru, this message translates to:
  /// **'Выключение…'**
  String get sysmShuttingDown;

  /// No description provided for @sysmTimeTitle.
  ///
  /// In ru, this message translates to:
  /// **'Время и часовой пояс'**
  String get sysmTimeTitle;

  /// No description provided for @sysmTimeDesc.
  ///
  /// In ru, this message translates to:
  /// **'Текущее время, часовой пояс и синхронизация по NTP'**
  String get sysmTimeDesc;

  /// No description provided for @sysmTimeCurrent.
  ///
  /// In ru, this message translates to:
  /// **'Текущее время'**
  String get sysmTimeCurrent;

  /// No description provided for @sysmTimezone.
  ///
  /// In ru, this message translates to:
  /// **'Часовой пояс'**
  String get sysmTimezone;

  /// No description provided for @sysmTimezoneSave.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить часовой пояс'**
  String get sysmTimezoneSave;

  /// No description provided for @sysmTimezoneSaved.
  ///
  /// In ru, this message translates to:
  /// **'Часовой пояс сохранён'**
  String get sysmTimezoneSaved;

  /// No description provided for @sysmTimezoneSaveError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось сохранить часовой пояс'**
  String get sysmTimezoneSaveError;

  /// No description provided for @sysmNtpSync.
  ///
  /// In ru, this message translates to:
  /// **'Синхронизировать время (NTP)'**
  String get sysmNtpSync;

  /// No description provided for @sysmNtpSyncing.
  ///
  /// In ru, this message translates to:
  /// **'Синхронизация…'**
  String get sysmNtpSyncing;

  /// No description provided for @sysmNtpDone.
  ///
  /// In ru, this message translates to:
  /// **'Время синхронизировано'**
  String get sysmNtpDone;

  /// No description provided for @sysmNtpFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось синхронизировать время'**
  String get sysmNtpFailed;

  /// No description provided for @sysmTerminalTitle.
  ///
  /// In ru, this message translates to:
  /// **'Терминал'**
  String get sysmTerminalTitle;

  /// No description provided for @sysmTerminalDesc.
  ///
  /// In ru, this message translates to:
  /// **'Диагностика и управление приставкой (командная строка)'**
  String get sysmTerminalDesc;

  /// No description provided for @sysmTerminalOpen.
  ///
  /// In ru, this message translates to:
  /// **'Открыть терминал'**
  String get sysmTerminalOpen;

  /// No description provided for @sysmTerminalRootNote.
  ///
  /// In ru, this message translates to:
  /// **'Команды выполняются как root на приставке.'**
  String get sysmTerminalRootNote;

  /// No description provided for @sysmTerminalHint.
  ///
  /// In ru, this message translates to:
  /// **'Введите команду (например: systemctl status telepos-sysd)'**
  String get sysmTerminalHint;

  /// No description provided for @sysmTerminalRun.
  ///
  /// In ru, this message translates to:
  /// **'Выполнить'**
  String get sysmTerminalRun;

  /// No description provided for @sysmTerminalClear.
  ///
  /// In ru, this message translates to:
  /// **'Очистить вывод'**
  String get sysmTerminalClear;

  /// No description provided for @sysmTerminalRunning.
  ///
  /// In ru, this message translates to:
  /// **'Выполняется…'**
  String get sysmTerminalRunning;

  /// No description provided for @sysmTerminalExitCode.
  ///
  /// In ru, this message translates to:
  /// **'Код возврата: {code}'**
  String sysmTerminalExitCode(int code);

  /// No description provided for @sysmTerminalEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Вывод появится здесь'**
  String get sysmTerminalEmpty;

  /// No description provided for @sysmTerminalHistory.
  ///
  /// In ru, this message translates to:
  /// **'История команд'**
  String get sysmTerminalHistory;

  /// No description provided for @sysmTerminalPresets.
  ///
  /// In ru, this message translates to:
  /// **'Пресеты'**
  String get sysmTerminalPresets;

  /// No description provided for @sysmTerminalPresetsNetwork.
  ///
  /// In ru, this message translates to:
  /// **'Сеть'**
  String get sysmTerminalPresetsNetwork;

  /// No description provided for @sysmTerminalPresetsPrinters.
  ///
  /// In ru, this message translates to:
  /// **'Принтеры'**
  String get sysmTerminalPresetsPrinters;

  /// No description provided for @sysmTerminalPresetsSystem.
  ///
  /// In ru, this message translates to:
  /// **'Система'**
  String get sysmTerminalPresetsSystem;

  /// No description provided for @sysmTerminalPresetsTime.
  ///
  /// In ru, this message translates to:
  /// **'Время'**
  String get sysmTerminalPresetsTime;

  /// No description provided for @sysmTermGroupDiagnostics.
  ///
  /// In ru, this message translates to:
  /// **'Диагностика'**
  String get sysmTermGroupDiagnostics;

  /// No description provided for @sysmTermGroupPrinter.
  ///
  /// In ru, this message translates to:
  /// **'Принтер'**
  String get sysmTermGroupPrinter;

  /// No description provided for @sysmTermGroupNetwork.
  ///
  /// In ru, this message translates to:
  /// **'Сеть'**
  String get sysmTermGroupNetwork;

  /// No description provided for @sysmTermGroupSystem.
  ///
  /// In ru, this message translates to:
  /// **'Система'**
  String get sysmTermGroupSystem;

  /// No description provided for @sysmTermGroupTime.
  ///
  /// In ru, this message translates to:
  /// **'Время'**
  String get sysmTermGroupTime;

  /// No description provided for @sysmTermDiagOsAndDaemon.
  ///
  /// In ru, this message translates to:
  /// **'Версия ОС и демона'**
  String get sysmTermDiagOsAndDaemon;

  /// No description provided for @sysmTermDiagNetworkStatus.
  ///
  /// In ru, this message translates to:
  /// **'Сеть: статус и адрес'**
  String get sysmTermDiagNetworkStatus;

  /// No description provided for @sysmTermDiagNetworkConnectivity.
  ///
  /// In ru, this message translates to:
  /// **'Сеть: связность'**
  String get sysmTermDiagNetworkConnectivity;

  /// No description provided for @sysmTermDiagHardware.
  ///
  /// In ru, this message translates to:
  /// **'Железо: диск/память/принтеры'**
  String get sysmTermDiagHardware;

  /// No description provided for @sysmTermPrinterFixAuto.
  ///
  /// In ru, this message translates to:
  /// **'Починить принтер (авто)'**
  String get sysmTermPrinterFixAuto;

  /// No description provided for @sysmTermPrinterDiag.
  ///
  /// In ru, this message translates to:
  /// **'Диагностика принтера'**
  String get sysmTermPrinterDiag;

  /// No description provided for @sysmTermPrinterLoadUsblp.
  ///
  /// In ru, this message translates to:
  /// **'Загрузить модуль usblp'**
  String get sysmTermPrinterLoadUsblp;

  /// No description provided for @sysmTermPrinterNodesAndPerms.
  ///
  /// In ru, this message translates to:
  /// **'Узлы принтера и права'**
  String get sysmTermPrinterNodesAndPerms;

  /// No description provided for @sysmTermPrinterLsusb.
  ///
  /// In ru, this message translates to:
  /// **'USB-устройства (lsusb)'**
  String get sysmTermPrinterLsusb;

  /// No description provided for @sysmTermPrinterCupsStatus.
  ///
  /// In ru, this message translates to:
  /// **'CUPS: статус и очереди'**
  String get sysmTermPrinterCupsStatus;

  /// No description provided for @sysmTermPrinterGiveToKernel.
  ///
  /// In ru, this message translates to:
  /// **'Отдать принтер ядру (usblp)'**
  String get sysmTermPrinterGiveToKernel;

  /// No description provided for @sysmTermPrinterTestPrint.
  ///
  /// In ru, this message translates to:
  /// **'Тест-печать на /dev/usb/lp0'**
  String get sysmTermPrinterTestPrint;

  /// No description provided for @sysmTermNetDeviceStatus.
  ///
  /// In ru, this message translates to:
  /// **'Статус устройств'**
  String get sysmTermNetDeviceStatus;

  /// No description provided for @sysmTermNetIpAddresses.
  ///
  /// In ru, this message translates to:
  /// **'IP-адреса'**
  String get sysmTermNetIpAddresses;

  /// No description provided for @sysmTermNetConnectEthernet.
  ///
  /// In ru, this message translates to:
  /// **'Подключить Ethernet'**
  String get sysmTermNetConnectEthernet;

  /// No description provided for @sysmTermNetReload.
  ///
  /// In ru, this message translates to:
  /// **'Перезагрузить сеть'**
  String get sysmTermNetReload;

  /// No description provided for @sysmTermNetPing.
  ///
  /// In ru, this message translates to:
  /// **'Пинг 8.8.8.8'**
  String get sysmTermNetPing;

  /// No description provided for @sysmTermSysDisk.
  ///
  /// In ru, this message translates to:
  /// **'Диск'**
  String get sysmTermSysDisk;

  /// No description provided for @sysmTermSysMemory.
  ///
  /// In ru, this message translates to:
  /// **'Память'**
  String get sysmTermSysMemory;

  /// No description provided for @sysmTermSysSysdStatus.
  ///
  /// In ru, this message translates to:
  /// **'Статус telepos-sysd'**
  String get sysmTermSysSysdStatus;

  /// No description provided for @sysmTermSysKioskLogs.
  ///
  /// In ru, this message translates to:
  /// **'Логи киоска'**
  String get sysmTermSysKioskLogs;

  /// No description provided for @sysmTermTimeDateTime.
  ///
  /// In ru, this message translates to:
  /// **'Дата и время'**
  String get sysmTermTimeDateTime;

  /// No description provided for @sysmTermTimeNtpSync.
  ///
  /// In ru, this message translates to:
  /// **'Синхронизация NTP'**
  String get sysmTermTimeNtpSync;

  /// No description provided for @labelPrinterDevicePath.
  ///
  /// In ru, this message translates to:
  /// **'Путь к устройству'**
  String get labelPrinterDevicePath;

  /// No description provided for @labelPrinterDevicePathHint.
  ///
  /// In ru, this message translates to:
  /// **'Например: /dev/usb/lp0 (USB) или /dev/ttyUSB0 (Serial). Оставьте пустым для значения по умолчанию.'**
  String get labelPrinterDevicePathHint;

  /// No description provided for @movementTitle.
  ///
  /// In ru, this message translates to:
  /// **'Перемещение'**
  String get movementTitle;

  /// No description provided for @movementTitleFull.
  ///
  /// In ru, this message translates to:
  /// **'Перемещение товаров'**
  String get movementTitleFull;

  /// No description provided for @movementFrom.
  ///
  /// In ru, this message translates to:
  /// **'Откуда *'**
  String get movementFrom;

  /// No description provided for @movementTo.
  ///
  /// In ru, this message translates to:
  /// **'Куда *'**
  String get movementTo;

  /// No description provided for @movementLocationHint.
  ///
  /// In ru, this message translates to:
  /// **'Название склада / точки'**
  String get movementLocationHint;

  /// No description provided for @movementProductsCount.
  ///
  /// In ru, this message translates to:
  /// **'Товаров: {count}'**
  String movementProductsCount(int count);

  /// No description provided for @movementSumLabel.
  ///
  /// In ru, this message translates to:
  /// **'Сумма: {amount}'**
  String movementSumLabel(String amount);

  /// No description provided for @movementAddProduct.
  ///
  /// In ru, this message translates to:
  /// **'Добавить товар'**
  String get movementAddProduct;

  /// No description provided for @movementBarcodeHint.
  ///
  /// In ru, this message translates to:
  /// **'Штрихкод или артикул'**
  String get movementBarcodeHint;

  /// No description provided for @movementComment.
  ///
  /// In ru, this message translates to:
  /// **'Комментарий'**
  String get movementComment;

  /// No description provided for @movementCommentHint.
  ///
  /// In ru, this message translates to:
  /// **'Примечание к перемещению...'**
  String get movementCommentHint;

  /// No description provided for @movementCommentHintShort.
  ///
  /// In ru, this message translates to:
  /// **'Примечание...'**
  String get movementCommentHintShort;

  /// No description provided for @movementProductNotFound.
  ///
  /// In ru, this message translates to:
  /// **'Товар не найден'**
  String get movementProductNotFound;

  /// No description provided for @movementSavedMessage.
  ///
  /// In ru, this message translates to:
  /// **'Перемещение сохранено: {count} товаров на {amount}'**
  String movementSavedMessage(int count, String amount);

  /// No description provided for @movementCancelTitle.
  ///
  /// In ru, this message translates to:
  /// **'Отменить перемещение?'**
  String get movementCancelTitle;

  /// No description provided for @movementCancelMessage.
  ///
  /// In ru, this message translates to:
  /// **'Все несохранённые данные будут потеряны.'**
  String get movementCancelMessage;

  /// No description provided for @movementCancelConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Да, отменить'**
  String get movementCancelConfirm;

  /// No description provided for @movementProductFallback.
  ///
  /// In ru, this message translates to:
  /// **'Товар #{ucode}'**
  String movementProductFallback(String ucode);

  /// No description provided for @movementPriceLabel.
  ///
  /// In ru, this message translates to:
  /// **'Цена'**
  String get movementPriceLabel;

  /// No description provided for @movementSaveError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка сохранения'**
  String get movementSaveError;

  /// No description provided for @movementEmptyTitle.
  ///
  /// In ru, this message translates to:
  /// **'Добавьте товары для перемещения'**
  String get movementEmptyTitle;

  /// No description provided for @movementEmptyHint.
  ///
  /// In ru, this message translates to:
  /// **'Отсканируйте штрихкод или введите вручную'**
  String get movementEmptyHint;

  /// No description provided for @supplierReturnTitle.
  ///
  /// In ru, this message translates to:
  /// **'Возврат поставщику'**
  String get supplierReturnTitle;

  /// No description provided for @supplierReturnProductsCount.
  ///
  /// In ru, this message translates to:
  /// **'Товаров: {count}'**
  String supplierReturnProductsCount(int count);

  /// No description provided for @supplierReturnSumLabel.
  ///
  /// In ru, this message translates to:
  /// **'Сумма: {amount}'**
  String supplierReturnSumLabel(String amount);

  /// No description provided for @supplierReturnSupplier.
  ///
  /// In ru, this message translates to:
  /// **'Поставщик *'**
  String get supplierReturnSupplier;

  /// No description provided for @supplierReturnSelectSupplier.
  ///
  /// In ru, this message translates to:
  /// **'Выберите поставщика'**
  String get supplierReturnSelectSupplier;

  /// No description provided for @supplierReturnAccount.
  ///
  /// In ru, this message translates to:
  /// **'Счёт возврата'**
  String get supplierReturnAccount;

  /// No description provided for @supplierReturnSelectAccount.
  ///
  /// In ru, this message translates to:
  /// **'Выберите счёт'**
  String get supplierReturnSelectAccount;

  /// No description provided for @supplierReturnAddProduct.
  ///
  /// In ru, this message translates to:
  /// **'Добавить товар'**
  String get supplierReturnAddProduct;

  /// No description provided for @supplierReturnBarcodeHint.
  ///
  /// In ru, this message translates to:
  /// **'Штрихкод или артикул'**
  String get supplierReturnBarcodeHint;

  /// No description provided for @supplierReturnComment.
  ///
  /// In ru, this message translates to:
  /// **'Комментарий'**
  String get supplierReturnComment;

  /// No description provided for @supplierReturnCommentHint.
  ///
  /// In ru, this message translates to:
  /// **'Причина возврата...'**
  String get supplierReturnCommentHint;

  /// No description provided for @supplierReturnProductNotFound.
  ///
  /// In ru, this message translates to:
  /// **'Товар не найден'**
  String get supplierReturnProductNotFound;

  /// No description provided for @supplierReturnSavedMessage.
  ///
  /// In ru, this message translates to:
  /// **'Возврат сохранён: {count} товаров на {amount}'**
  String supplierReturnSavedMessage(int count, String amount);

  /// No description provided for @supplierReturnCancelTitle.
  ///
  /// In ru, this message translates to:
  /// **'Отменить возврат?'**
  String get supplierReturnCancelTitle;

  /// No description provided for @supplierReturnCancelMessage.
  ///
  /// In ru, this message translates to:
  /// **'Все несохранённые данные будут потеряны.'**
  String get supplierReturnCancelMessage;

  /// No description provided for @supplierReturnCancelConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Да, отменить'**
  String get supplierReturnCancelConfirm;

  /// No description provided for @supplierReturnProductFallback.
  ///
  /// In ru, this message translates to:
  /// **'Товар #{ucode}'**
  String supplierReturnProductFallback(String ucode);

  /// No description provided for @supplierReturnNoSuppliers.
  ///
  /// In ru, this message translates to:
  /// **'Нет поставщиков'**
  String get supplierReturnNoSuppliers;

  /// No description provided for @supplierReturnNoAccounts.
  ///
  /// In ru, this message translates to:
  /// **'Нет счетов'**
  String get supplierReturnNoAccounts;

  /// No description provided for @supplierReturnBalance.
  ///
  /// In ru, this message translates to:
  /// **'Баланс: {amount}'**
  String supplierReturnBalance(String amount);

  /// No description provided for @supplierReturnPriceLabel.
  ///
  /// In ru, this message translates to:
  /// **'Цена'**
  String get supplierReturnPriceLabel;

  /// No description provided for @supplierReturnSaveError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка сохранения'**
  String get supplierReturnSaveError;

  /// No description provided for @supplierReturnEmptyTitle.
  ///
  /// In ru, this message translates to:
  /// **'Добавьте товары для возврата'**
  String get supplierReturnEmptyTitle;

  /// No description provided for @supplierReturnEmptyHint.
  ///
  /// In ru, this message translates to:
  /// **'Отсканируйте штрихкод или введите вручную'**
  String get supplierReturnEmptyHint;

  /// No description provided for @esfSettingsTitle.
  ///
  /// In ru, this message translates to:
  /// **'ЭСФ (электронные счета-фактуры)'**
  String get esfSettingsTitle;

  /// No description provided for @esfSettingsSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Реквизиты, ЭЦП, исходящие документы'**
  String get esfSettingsSubtitle;

  /// No description provided for @esfSettingsSave.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить'**
  String get esfSettingsSave;

  /// No description provided for @esfSettingsSaved.
  ///
  /// In ru, this message translates to:
  /// **'Настройки ЭСФ сохранены'**
  String get esfSettingsSaved;

  /// No description provided for @esfSettingsSaveError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка сохранения настроек ЭСФ'**
  String get esfSettingsSaveError;

  /// No description provided for @esfSettingsEnable.
  ///
  /// In ru, this message translates to:
  /// **'Включить ЭСФ'**
  String get esfSettingsEnable;

  /// No description provided for @esfSettingsEnableSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Формировать счета-фактуры по продажам B2B (по БИН покупателя)'**
  String get esfSettingsEnableSubtitle;

  /// No description provided for @esfSettingsOperator.
  ///
  /// In ru, this message translates to:
  /// **'Оператор ЭСФ'**
  String get esfSettingsOperator;

  /// No description provided for @esfSettingsTestMode.
  ///
  /// In ru, this message translates to:
  /// **'Тестовый режим'**
  String get esfSettingsTestMode;

  /// No description provided for @esfSettingsSupplier.
  ///
  /// In ru, this message translates to:
  /// **'Реквизиты поставщика (наша организация)'**
  String get esfSettingsSupplier;

  /// No description provided for @esfSettingsBin.
  ///
  /// In ru, this message translates to:
  /// **'БИН/ИИН'**
  String get esfSettingsBin;

  /// No description provided for @esfSettingsName.
  ///
  /// In ru, this message translates to:
  /// **'Наименование'**
  String get esfSettingsName;

  /// No description provided for @esfSettingsAddress.
  ///
  /// In ru, this message translates to:
  /// **'Адрес'**
  String get esfSettingsAddress;

  /// No description provided for @esfSettingsVatPayer.
  ///
  /// In ru, this message translates to:
  /// **'Плательщик НДС'**
  String get esfSettingsVatPayer;

  /// No description provided for @esfSettingsVatSeries.
  ///
  /// In ru, this message translates to:
  /// **'Серия свидетельства НДС'**
  String get esfSettingsVatSeries;

  /// No description provided for @esfSettingsVatNumber.
  ///
  /// In ru, this message translates to:
  /// **'Номер свидетельства НДС'**
  String get esfSettingsVatNumber;

  /// No description provided for @esfSettingsVatRate.
  ///
  /// In ru, this message translates to:
  /// **'Ставка НДС, %'**
  String get esfSettingsVatRate;

  /// No description provided for @esfSettingsEcp.
  ///
  /// In ru, this message translates to:
  /// **'ЭЦП (НУЦ РК)'**
  String get esfSettingsEcp;

  /// No description provided for @esfSettingsEcpKeyPath.
  ///
  /// In ru, this message translates to:
  /// **'Путь к ключу ЭЦП'**
  String get esfSettingsEcpKeyPath;

  /// No description provided for @esfSettingsEcpKeyAlias.
  ///
  /// In ru, this message translates to:
  /// **'Алиас ключа'**
  String get esfSettingsEcpKeyAlias;

  /// No description provided for @esfSettingsB2bOnly.
  ///
  /// In ru, this message translates to:
  /// **'Только B2B'**
  String get esfSettingsB2bOnly;

  /// No description provided for @esfSettingsB2bOnlySubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Не формировать ЭСФ для розничных продаж физлицам'**
  String get esfSettingsB2bOnlySubtitle;

  /// No description provided for @esfSettingsEcpHint.
  ///
  /// In ru, this message translates to:
  /// **'Для реальной выписки требуется ЭЦП НУЦ РК и профиль ИС ЭСФ. Черновики формируются и хранятся офлайн без ЭЦП.'**
  String get esfSettingsEcpHint;

  /// No description provided for @esfSettingsWebkassaNote.
  ///
  /// In ru, this message translates to:
  /// **'Реквизиты выписки (ЭЦП, подключение, токен) берутся из настроек WebKassa (Фискализация) — один общий конфиг. Отдельная настройка ЭСФ-реквизитов здесь не требуется.'**
  String get esfSettingsWebkassaNote;

  /// No description provided for @esfOutboxTitle.
  ///
  /// In ru, this message translates to:
  /// **'Исходящие ЭСФ'**
  String get esfOutboxTitle;

  /// No description provided for @esfOutboxEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Нет документов ЭСФ'**
  String get esfOutboxEmpty;

  /// No description provided for @esfOutboxEmptyHint.
  ///
  /// In ru, this message translates to:
  /// **'Счета-фактуры появятся здесь после продаж B2B'**
  String get esfOutboxEmptyHint;

  /// No description provided for @esfOutboxRetry.
  ///
  /// In ru, this message translates to:
  /// **'Повторить отправку'**
  String get esfOutboxRetry;

  /// No description provided for @esfOutboxRetryAll.
  ///
  /// In ru, this message translates to:
  /// **'Повторить все'**
  String get esfOutboxRetryAll;

  /// No description provided for @esfOutboxRetryDone.
  ///
  /// In ru, this message translates to:
  /// **'Обработано: доставлено {delivered}, в очереди {queued}, ошибок {failed}'**
  String esfOutboxRetryDone(int delivered, int queued, int failed);

  /// No description provided for @esfOutboxStatusDraft.
  ///
  /// In ru, this message translates to:
  /// **'Черновик'**
  String get esfOutboxStatusDraft;

  /// No description provided for @esfOutboxStatusQueued.
  ///
  /// In ru, this message translates to:
  /// **'В очереди'**
  String get esfOutboxStatusQueued;

  /// No description provided for @esfOutboxStatusSubmitted.
  ///
  /// In ru, this message translates to:
  /// **'Отправлен'**
  String get esfOutboxStatusSubmitted;

  /// No description provided for @esfOutboxStatusDelivered.
  ///
  /// In ru, this message translates to:
  /// **'Зарегистрирован'**
  String get esfOutboxStatusDelivered;

  /// No description provided for @esfOutboxStatusRejected.
  ///
  /// In ru, this message translates to:
  /// **'Отклонён'**
  String get esfOutboxStatusRejected;

  /// No description provided for @esfOutboxStatusRevoked.
  ///
  /// In ru, this message translates to:
  /// **'Отозван'**
  String get esfOutboxStatusRevoked;

  /// No description provided for @esfOutboxStatusError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка'**
  String get esfOutboxStatusError;

  /// No description provided for @esfOutboxAttempts.
  ///
  /// In ru, this message translates to:
  /// **'Попыток: {count}'**
  String esfOutboxAttempts(int count);

  /// No description provided for @esfOutboxRegNumber.
  ///
  /// In ru, this message translates to:
  /// **'Рег. №: {number}'**
  String esfOutboxRegNumber(String number);

  /// No description provided for @sntTitle.
  ///
  /// In ru, this message translates to:
  /// **'СНТ (сопроводительные накладные)'**
  String get sntTitle;

  /// No description provided for @sntSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Виртуальный склад, движение товаров'**
  String get sntSubtitle;

  /// No description provided for @sntEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Нет документов СНТ'**
  String get sntEmpty;

  /// No description provided for @sntEmptyHint.
  ///
  /// In ru, this message translates to:
  /// **'СНТ формируются автоматически после приёмки прослеживаемых товаров'**
  String get sntEmptyHint;

  /// No description provided for @sntRefresh.
  ///
  /// In ru, this message translates to:
  /// **'Обновить очередь'**
  String get sntRefresh;

  /// No description provided for @sntDrainDone.
  ///
  /// In ru, this message translates to:
  /// **'Обработано: отправлено {submitted}, в очереди {remaining}, ошибок {failed}'**
  String sntDrainDone(int submitted, int remaining, int failed);

  /// No description provided for @sntDirectionInbound.
  ///
  /// In ru, this message translates to:
  /// **'Входящая'**
  String get sntDirectionInbound;

  /// No description provided for @sntDirectionOutbound.
  ///
  /// In ru, this message translates to:
  /// **'Исходящая'**
  String get sntDirectionOutbound;

  /// No description provided for @sntStatusDraft.
  ///
  /// In ru, this message translates to:
  /// **'Черновик'**
  String get sntStatusDraft;

  /// No description provided for @sntStatusQueued.
  ///
  /// In ru, this message translates to:
  /// **'В очереди'**
  String get sntStatusQueued;

  /// No description provided for @sntStatusRegistered.
  ///
  /// In ru, this message translates to:
  /// **'Зарегистрирована'**
  String get sntStatusRegistered;

  /// No description provided for @sntStatusDelivered.
  ///
  /// In ru, this message translates to:
  /// **'Доставлена'**
  String get sntStatusDelivered;

  /// No description provided for @sntStatusConfirmed.
  ///
  /// In ru, this message translates to:
  /// **'Подтверждена'**
  String get sntStatusConfirmed;

  /// No description provided for @sntStatusRejected.
  ///
  /// In ru, this message translates to:
  /// **'Отклонена'**
  String get sntStatusRejected;

  /// No description provided for @sntStatusRevoked.
  ///
  /// In ru, this message translates to:
  /// **'Отозвана'**
  String get sntStatusRevoked;

  /// No description provided for @sntStatusAnnulled.
  ///
  /// In ru, this message translates to:
  /// **'Аннулирована'**
  String get sntStatusAnnulled;

  /// No description provided for @sntStatusFailed.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка'**
  String get sntStatusFailed;

  /// No description provided for @sntLinesCount.
  ///
  /// In ru, this message translates to:
  /// **'Позиций: {count}'**
  String sntLinesCount(int count);

  /// No description provided for @sntRegNumber.
  ///
  /// In ru, this message translates to:
  /// **'Рег. №: {number}'**
  String sntRegNumber(String number);

  /// No description provided for @sntNotConfigured.
  ///
  /// In ru, this message translates to:
  /// **'СНТ / Виртуальный склад не настроены. Документы хранятся локально и будут отправлены после настройки ЭЦП.'**
  String get sntNotConfigured;

  /// No description provided for @sntConfigure.
  ///
  /// In ru, this message translates to:
  /// **'Настроить СНТ'**
  String get sntConfigure;

  /// No description provided for @sntSettingsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Настройки СНТ'**
  String get sntSettingsTitle;

  /// No description provided for @sntSettingsOperator.
  ///
  /// In ru, this message translates to:
  /// **'Оператор / способ отправки'**
  String get sntSettingsOperator;

  /// No description provided for @sntSettingsEnable.
  ///
  /// In ru, this message translates to:
  /// **'Включить СНТ'**
  String get sntSettingsEnable;

  /// No description provided for @sntSettingsEnableSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Сборка и отправка сопроводительных накладных (ИС ЭСФ)'**
  String get sntSettingsEnableSubtitle;

  /// No description provided for @sntSettingsProvider.
  ///
  /// In ru, this message translates to:
  /// **'Способ отправки'**
  String get sntSettingsProvider;

  /// No description provided for @sntSettingsTestMode.
  ///
  /// In ru, this message translates to:
  /// **'Тестовый режим'**
  String get sntSettingsTestMode;

  /// No description provided for @sntSettingsRequisites.
  ///
  /// In ru, this message translates to:
  /// **'Реквизиты налогоплательщика'**
  String get sntSettingsRequisites;

  /// No description provided for @sntSettingsOwnBin.
  ///
  /// In ru, this message translates to:
  /// **'БИН / ИИН (наш)'**
  String get sntSettingsOwnBin;

  /// No description provided for @sntSettingsWarehouseCode.
  ///
  /// In ru, this message translates to:
  /// **'Код виртуального склада'**
  String get sntSettingsWarehouseCode;

  /// No description provided for @sntSettingsBackend.
  ///
  /// In ru, this message translates to:
  /// **'TelePOS backend (прокси ИС ЭСФ)'**
  String get sntSettingsBackend;

  /// No description provided for @sntSettingsBackendUrl.
  ///
  /// In ru, this message translates to:
  /// **'URL бэкенда'**
  String get sntSettingsBackendUrl;

  /// No description provided for @sntSettingsApiKey.
  ///
  /// In ru, this message translates to:
  /// **'API-ключ'**
  String get sntSettingsApiKey;

  /// No description provided for @sntSettingsEcp.
  ///
  /// In ru, this message translates to:
  /// **'ЭЦП (НУЦ РК)'**
  String get sntSettingsEcp;

  /// No description provided for @sntSettingsCertPath.
  ///
  /// In ru, this message translates to:
  /// **'Путь к ключу ЭЦП'**
  String get sntSettingsCertPath;

  /// No description provided for @sntSettingsCertPassword.
  ///
  /// In ru, this message translates to:
  /// **'Пароль ключа'**
  String get sntSettingsCertPassword;

  /// No description provided for @sntSettingsEcpHint.
  ///
  /// In ru, this message translates to:
  /// **'Реальная отправка СНТ требует ЭЦП НУЦ РК и зарегистрированного профиля ИС ЭСФ. Без ЭЦП документы собираются и хранятся локально (Виртуальный склад работает офлайн).'**
  String get sntSettingsEcpHint;

  /// No description provided for @sntSettingsSharedEsfHint.
  ///
  /// In ru, this message translates to:
  /// **'СНТ и ЭСФ — подсистемы КГД. БИН и ЭЦП можно настроить на экране ЭСФ.'**
  String get sntSettingsSharedEsfHint;

  /// No description provided for @sntSettingsWebkassaNote.
  ///
  /// In ru, this message translates to:
  /// **'Реквизиты подключения (логин, apiKey, касса, ЭЦП) берутся из настроек WebKassa (Фискализация) — один общий конфиг.'**
  String get sntSettingsWebkassaNote;

  /// No description provided for @sntSettingsOpenEsf.
  ///
  /// In ru, this message translates to:
  /// **'Настройки ЭСФ'**
  String get sntSettingsOpenEsf;

  /// No description provided for @sntSettingsSave.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить'**
  String get sntSettingsSave;

  /// No description provided for @sntSettingsSaved.
  ///
  /// In ru, this message translates to:
  /// **'Настройки СНТ сохранены'**
  String get sntSettingsSaved;

  /// No description provided for @sntSettingsSaveError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось сохранить настройки СНТ'**
  String get sntSettingsSaveError;

  /// No description provided for @sntSettingsBinRequired.
  ///
  /// In ru, this message translates to:
  /// **'Укажите БИН / ИИН налогоплательщика'**
  String get sntSettingsBinRequired;

  /// No description provided for @esutdTitle.
  ///
  /// In ru, this message translates to:
  /// **'ЕСУТД (электронные ТТН)'**
  String get esutdTitle;

  /// No description provided for @esutdSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Товарно-транспортные накладные (e-waybill)'**
  String get esutdSubtitle;

  /// No description provided for @esutdNotConfigured.
  ///
  /// In ru, this message translates to:
  /// **'ЕСУТД не настроена. Укажите логин портала, чтобы загружать ТТН.'**
  String get esutdNotConfigured;

  /// No description provided for @esutdNotConfiguredShort.
  ///
  /// In ru, this message translates to:
  /// **'ЕСУТД не настроена'**
  String get esutdNotConfiguredShort;

  /// No description provided for @esutdConfigure.
  ///
  /// In ru, this message translates to:
  /// **'Настроить ЕСУТД'**
  String get esutdConfigure;

  /// No description provided for @esutdRefresh.
  ///
  /// In ru, this message translates to:
  /// **'Обновить'**
  String get esutdRefresh;

  /// No description provided for @esutdInbound.
  ///
  /// In ru, this message translates to:
  /// **'Входящие ТТН'**
  String get esutdInbound;

  /// No description provided for @esutdOutbound.
  ///
  /// In ru, this message translates to:
  /// **'Исходящие ТТН'**
  String get esutdOutbound;

  /// No description provided for @esutdEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Нет ТТН'**
  String get esutdEmpty;

  /// No description provided for @esutdWaybillNumber.
  ///
  /// In ru, this message translates to:
  /// **'ТТН № {number}'**
  String esutdWaybillNumber(String number);

  /// No description provided for @esutdCargoCount.
  ///
  /// In ru, this message translates to:
  /// **'Грузов: {count}'**
  String esutdCargoCount(int count);

  /// No description provided for @esutdSettingsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Настройки ЕСУТД'**
  String get esutdSettingsTitle;

  /// No description provided for @esutdSettingsConnection.
  ///
  /// In ru, this message translates to:
  /// **'Подключение'**
  String get esutdSettingsConnection;

  /// No description provided for @esutdSettingsEnable.
  ///
  /// In ru, this message translates to:
  /// **'Включить ЕСУТД'**
  String get esutdSettingsEnable;

  /// No description provided for @esutdSettingsEnableSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Загрузка и отправка электронных ТТН (esutd.gov.kz)'**
  String get esutdSettingsEnableSubtitle;

  /// No description provided for @esutdSettingsCredentials.
  ///
  /// In ru, this message translates to:
  /// **'Учётные данные портала'**
  String get esutdSettingsCredentials;

  /// No description provided for @esutdSettingsEmail.
  ///
  /// In ru, this message translates to:
  /// **'Email (логин портала)'**
  String get esutdSettingsEmail;

  /// No description provided for @esutdSettingsPassword.
  ///
  /// In ru, this message translates to:
  /// **'Пароль'**
  String get esutdSettingsPassword;

  /// No description provided for @esutdSettingsApiUrl.
  ///
  /// In ru, this message translates to:
  /// **'URL API (необязательно)'**
  String get esutdSettingsApiUrl;

  /// No description provided for @esutdSettingsApiUrlHint.
  ///
  /// In ru, this message translates to:
  /// **'Оставьте пустым для значения по умолчанию: https://esutd.gov.kz/api'**
  String get esutdSettingsApiUrlHint;

  /// No description provided for @esutdSettingsTestLogin.
  ///
  /// In ru, this message translates to:
  /// **'Проверить вход / Войти'**
  String get esutdSettingsTestLogin;

  /// No description provided for @esutdSettingsSessionActive.
  ///
  /// In ru, this message translates to:
  /// **'Сессия активна'**
  String get esutdSettingsSessionActive;

  /// No description provided for @esutdSettingsLoginOk.
  ///
  /// In ru, this message translates to:
  /// **'Вход в ЕСУТД выполнен'**
  String get esutdSettingsLoginOk;

  /// No description provided for @esutdSettingsLoginError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка входа: {error}'**
  String esutdSettingsLoginError(String error);

  /// No description provided for @esutdSettingsCredsRequired.
  ///
  /// In ru, this message translates to:
  /// **'Укажите email и пароль портала ЕСУТД'**
  String get esutdSettingsCredsRequired;

  /// No description provided for @esutdSettingsSave.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить'**
  String get esutdSettingsSave;

  /// No description provided for @esutdSettingsSaved.
  ///
  /// In ru, this message translates to:
  /// **'Настройки ЕСУТД сохранены'**
  String get esutdSettingsSaved;

  /// No description provided for @esutdSettingsSaveError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось сохранить настройки ЕСУТД'**
  String get esutdSettingsSaveError;

  /// No description provided for @esutdSettingsHint.
  ///
  /// In ru, this message translates to:
  /// **'ЕСУТД не имеет публичного API. Интеграция использует внутренние эндпоинты портала: вход по логину/паролю даёт сессию, которая переиспользуется и автоматически обновляется. Создание/подтверждение ТТН требует сложных справочников (КАТО, классификатор товаров, перевозчики) и пока недоступно из POS.'**
  String get esutdSettingsHint;

  /// No description provided for @ismptSettingsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Настройки ИС МПТ'**
  String get ismptSettingsTitle;

  /// No description provided for @ismptSettingsSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Маркировка (Честный знак KZ)'**
  String get ismptSettingsSubtitle;

  /// No description provided for @ismptSettingsOperator.
  ///
  /// In ru, this message translates to:
  /// **'Оператор / способ отправки'**
  String get ismptSettingsOperator;

  /// No description provided for @ismptSettingsEnable.
  ///
  /// In ru, this message translates to:
  /// **'Включить ИС МПТ'**
  String get ismptSettingsEnable;

  /// No description provided for @ismptSettingsEnableSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Проверка и отправка кодов маркировки (ismet.kz / Tañba)'**
  String get ismptSettingsEnableSubtitle;

  /// No description provided for @ismptSettingsBackend.
  ///
  /// In ru, this message translates to:
  /// **'Бэкенд'**
  String get ismptSettingsBackend;

  /// No description provided for @ismptSettingsTestMode.
  ///
  /// In ru, this message translates to:
  /// **'Тестовый режим'**
  String get ismptSettingsTestMode;

  /// No description provided for @ismptSettingsRequisites.
  ///
  /// In ru, this message translates to:
  /// **'Реквизиты налогоплательщика'**
  String get ismptSettingsRequisites;

  /// No description provided for @ismptSettingsOwnBin.
  ///
  /// In ru, this message translates to:
  /// **'БИН / ИИН (наш)'**
  String get ismptSettingsOwnBin;

  /// No description provided for @ismptSettingsApi.
  ///
  /// In ru, this message translates to:
  /// **'True API (ismet.kz)'**
  String get ismptSettingsApi;

  /// No description provided for @ismptSettingsApiUrl.
  ///
  /// In ru, this message translates to:
  /// **'URL API'**
  String get ismptSettingsApiUrl;

  /// No description provided for @ismptSettingsApiKey.
  ///
  /// In ru, this message translates to:
  /// **'API-ключ / токен'**
  String get ismptSettingsApiKey;

  /// No description provided for @ismptSettingsEcp.
  ///
  /// In ru, this message translates to:
  /// **'ЭЦП (НУЦ РК)'**
  String get ismptSettingsEcp;

  /// No description provided for @ismptSettingsCertPath.
  ///
  /// In ru, this message translates to:
  /// **'Путь к ключу ЭЦП'**
  String get ismptSettingsCertPath;

  /// No description provided for @ismptSettingsCertPassword.
  ///
  /// In ru, this message translates to:
  /// **'Пароль ключа'**
  String get ismptSettingsCertPassword;

  /// No description provided for @ismptSettingsEcpHint.
  ///
  /// In ru, this message translates to:
  /// **'Реальная работа с ИС МПТ требует ЭЦП НУЦ РК и зарегистрированного профиля участника оборота. Без ЭЦП коды маркировки принимаются и хранятся локально (приёмка работает офлайн, продажа не блокируется).'**
  String get ismptSettingsEcpHint;

  /// No description provided for @ismptSettingsSharedEsfHint.
  ///
  /// In ru, this message translates to:
  /// **'ИС МПТ и ЭСФ — подсистемы КГД. БИН и ЭЦП можно настроить на экране ЭСФ.'**
  String get ismptSettingsSharedEsfHint;

  /// No description provided for @ismptSettingsWebkassaNote.
  ///
  /// In ru, this message translates to:
  /// **'Проверка кодов маркировки идёт через WebKassa. Реквизиты подключения (логин, apiKey, касса, ЭЦП) берутся из настроек WebKassa (Фискализация) — один общий конфиг.'**
  String get ismptSettingsWebkassaNote;

  /// No description provided for @ismptSettingsOpenEsf.
  ///
  /// In ru, this message translates to:
  /// **'Настройки ЭСФ'**
  String get ismptSettingsOpenEsf;

  /// No description provided for @ismptSettingsSave.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить'**
  String get ismptSettingsSave;

  /// No description provided for @ismptSettingsSaved.
  ///
  /// In ru, this message translates to:
  /// **'Настройки ИС МПТ сохранены'**
  String get ismptSettingsSaved;

  /// No description provided for @ismptSettingsSaveError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось сохранить настройки ИС МПТ'**
  String get ismptSettingsSaveError;

  /// No description provided for @ismptSettingsBinRequired.
  ///
  /// In ru, this message translates to:
  /// **'Укажите БИН / ИИН налогоплательщика'**
  String get ismptSettingsBinRequired;

  /// No description provided for @reorderRulesTitle.
  ///
  /// In ru, this message translates to:
  /// **'Правила перезаказа'**
  String get reorderRulesTitle;

  /// No description provided for @reorderRulesSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Минимальный остаток по товарам'**
  String get reorderRulesSubtitle;

  /// No description provided for @reorderRulesEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Нет правил перезаказа'**
  String get reorderRulesEmpty;

  /// No description provided for @reorderRulesEmptyHint.
  ///
  /// In ru, this message translates to:
  /// **'Задайте минимальный остаток для товаров, чтобы получать сигналы дозаказа'**
  String get reorderRulesEmptyHint;

  /// No description provided for @reorderRulesAdd.
  ///
  /// In ru, this message translates to:
  /// **'Добавить правило'**
  String get reorderRulesAdd;

  /// No description provided for @reorderRulesMinStock.
  ///
  /// In ru, this message translates to:
  /// **'Минимальный остаток'**
  String get reorderRulesMinStock;

  /// No description provided for @reorderRulesReorderQty.
  ///
  /// In ru, this message translates to:
  /// **'Размер заказа'**
  String get reorderRulesReorderQty;

  /// No description provided for @reorderRulesProduct.
  ///
  /// In ru, this message translates to:
  /// **'Товар (ucode)'**
  String get reorderRulesProduct;

  /// No description provided for @reorderRulesProductHint.
  ///
  /// In ru, this message translates to:
  /// **'Код товара'**
  String get reorderRulesProductHint;

  /// No description provided for @reorderRulesSave.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить'**
  String get reorderRulesSave;

  /// No description provided for @reorderRulesSaved.
  ///
  /// In ru, this message translates to:
  /// **'Правило сохранено'**
  String get reorderRulesSaved;

  /// No description provided for @reorderRulesInvalid.
  ///
  /// In ru, this message translates to:
  /// **'Укажите код товара и минимальный остаток'**
  String get reorderRulesInvalid;

  /// No description provided for @reorderRulesBelowPoint.
  ///
  /// In ru, this message translates to:
  /// **'Ниже точки перезаказа: {count}'**
  String reorderRulesBelowPoint(int count);

  /// No description provided for @reorderRulesEditTitle.
  ///
  /// In ru, this message translates to:
  /// **'Правило перезаказа'**
  String get reorderRulesEditTitle;

  /// No description provided for @supplierOrderRuleBased.
  ///
  /// In ru, this message translates to:
  /// **'По правилам перезаказа'**
  String get supplierOrderRuleBased;

  /// No description provided for @supplierOrderGlobalThreshold.
  ///
  /// In ru, this message translates to:
  /// **'Глобальный порог ({threshold})'**
  String supplierOrderGlobalThreshold(String threshold);

  /// No description provided for @catalogPageFirst.
  ///
  /// In ru, this message translates to:
  /// **'Первая'**
  String get catalogPageFirst;

  /// No description provided for @catalogPagePrev.
  ///
  /// In ru, this message translates to:
  /// **'Назад'**
  String get catalogPagePrev;

  /// No description provided for @catalogPageNext.
  ///
  /// In ru, this message translates to:
  /// **'Вперёд'**
  String get catalogPageNext;

  /// No description provided for @catalogPageLast.
  ///
  /// In ru, this message translates to:
  /// **'Последняя'**
  String get catalogPageLast;

  /// No description provided for @catalogGoToPage.
  ///
  /// In ru, this message translates to:
  /// **'Перейти к странице'**
  String get catalogGoToPage;

  /// No description provided for @catalogPageOf.
  ///
  /// In ru, this message translates to:
  /// **'Страница из {total}'**
  String catalogPageOf(int total);

  /// No description provided for @shiftClosedGateTitle.
  ///
  /// In ru, this message translates to:
  /// **'Смена закрыта'**
  String get shiftClosedGateTitle;

  /// No description provided for @shiftClosedGateMessage.
  ///
  /// In ru, this message translates to:
  /// **'Откройте смену, чтобы продолжить работу с операциями.'**
  String get shiftClosedGateMessage;

  /// No description provided for @shiftClosedGateOpen.
  ///
  /// In ru, this message translates to:
  /// **'Открыть смену'**
  String get shiftClosedGateOpen;

  /// No description provided for @sysmTerminalPresetsDiag.
  ///
  /// In ru, this message translates to:
  /// **'Диагностика'**
  String get sysmTerminalPresetsDiag;

  /// No description provided for @wmsDashboardTitle.
  ///
  /// In ru, this message translates to:
  /// **'WMS — Управление складом'**
  String get wmsDashboardTitle;

  /// No description provided for @wmsDashboardTitleShort.
  ///
  /// In ru, this message translates to:
  /// **'WMS — Склад'**
  String get wmsDashboardTitleShort;

  /// No description provided for @wmsSettings.
  ///
  /// In ru, this message translates to:
  /// **'Настройки WMS'**
  String get wmsSettings;

  /// No description provided for @wmsSettingsSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Конфигурация модулей'**
  String get wmsSettingsSubtitle;

  /// No description provided for @wmsModuleWarehouses.
  ///
  /// In ru, this message translates to:
  /// **'Склады'**
  String get wmsModuleWarehouses;

  /// No description provided for @wmsModuleWarehousesSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Склады, зоны, ячейки'**
  String get wmsModuleWarehousesSubtitle;

  /// No description provided for @wmsModuleBatches.
  ///
  /// In ru, this message translates to:
  /// **'Партии'**
  String get wmsModuleBatches;

  /// No description provided for @wmsModuleBatchesSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Партионный учёт'**
  String get wmsModuleBatchesSubtitle;

  /// No description provided for @wmsModuleCellStock.
  ///
  /// In ru, this message translates to:
  /// **'Остатки по ячейкам'**
  String get wmsModuleCellStock;

  /// No description provided for @wmsModuleCellStockSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Остатки, размещение, отбор'**
  String get wmsModuleCellStockSubtitle;

  /// No description provided for @wmsModuleSerials.
  ///
  /// In ru, this message translates to:
  /// **'Серийный учёт'**
  String get wmsModuleSerials;

  /// No description provided for @wmsModuleSerialsSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Серийные номера'**
  String get wmsModuleSerialsSubtitle;

  /// No description provided for @wmsModuleMarking.
  ///
  /// In ru, this message translates to:
  /// **'Маркировка'**
  String get wmsModuleMarking;

  /// No description provided for @wmsModuleMarkingSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Коды маркировки'**
  String get wmsModuleMarkingSubtitle;

  /// No description provided for @wmsModuleClaims.
  ///
  /// In ru, this message translates to:
  /// **'Рекламации'**
  String get wmsModuleClaims;

  /// No description provided for @wmsModuleClaimsSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Претензии и возвраты'**
  String get wmsModuleClaimsSubtitle;

  /// No description provided for @wmsWarehousesAndCells.
  ///
  /// In ru, this message translates to:
  /// **'Склады и ячейки'**
  String get wmsWarehousesAndCells;

  /// No description provided for @wmsWarehouses.
  ///
  /// In ru, this message translates to:
  /// **'Склады'**
  String get wmsWarehouses;

  /// No description provided for @wmsAddWarehouse.
  ///
  /// In ru, this message translates to:
  /// **'Добавить склад'**
  String get wmsAddWarehouse;

  /// No description provided for @wmsNoWarehouses.
  ///
  /// In ru, this message translates to:
  /// **'Нет складов'**
  String get wmsNoWarehouses;

  /// No description provided for @wmsNoName.
  ///
  /// In ru, this message translates to:
  /// **'Без имени'**
  String get wmsNoName;

  /// No description provided for @wmsZones.
  ///
  /// In ru, this message translates to:
  /// **'Зоны'**
  String get wmsZones;

  /// No description provided for @wmsZonesNamed.
  ///
  /// In ru, this message translates to:
  /// **'Зоны: {name}'**
  String wmsZonesNamed(String name);

  /// No description provided for @wmsAddZone.
  ///
  /// In ru, this message translates to:
  /// **'Добавить зону'**
  String get wmsAddZone;

  /// No description provided for @wmsSelectWarehouse.
  ///
  /// In ru, this message translates to:
  /// **'Выберите склад'**
  String get wmsSelectWarehouse;

  /// No description provided for @wmsNoZones.
  ///
  /// In ru, this message translates to:
  /// **'Нет зон'**
  String get wmsNoZones;

  /// No description provided for @wmsCells.
  ///
  /// In ru, this message translates to:
  /// **'Ячейки'**
  String get wmsCells;

  /// No description provided for @wmsCellsNamed.
  ///
  /// In ru, this message translates to:
  /// **'Ячейки: {name}'**
  String wmsCellsNamed(String name);

  /// No description provided for @wmsGenerate.
  ///
  /// In ru, this message translates to:
  /// **'Генерировать'**
  String get wmsGenerate;

  /// No description provided for @wmsSelectZone.
  ///
  /// In ru, this message translates to:
  /// **'Выберите зону'**
  String get wmsSelectZone;

  /// No description provided for @wmsNoCells.
  ///
  /// In ru, this message translates to:
  /// **'Нет ячеек'**
  String get wmsNoCells;

  /// No description provided for @wmsNoAddress.
  ///
  /// In ru, this message translates to:
  /// **'Без адреса'**
  String get wmsNoAddress;

  /// No description provided for @wmsCellBlocked.
  ///
  /// In ru, this message translates to:
  /// **'Заблокирована'**
  String get wmsCellBlocked;

  /// No description provided for @wmsCellsCount.
  ///
  /// In ru, this message translates to:
  /// **'{count} ячеек'**
  String wmsCellsCount(int count);

  /// No description provided for @wmsNewWarehouse.
  ///
  /// In ru, this message translates to:
  /// **'Новый склад'**
  String get wmsNewWarehouse;

  /// No description provided for @wmsWarehouseCode.
  ///
  /// In ru, this message translates to:
  /// **'Код склада'**
  String get wmsWarehouseCode;

  /// No description provided for @wmsName.
  ///
  /// In ru, this message translates to:
  /// **'Наименование'**
  String get wmsName;

  /// No description provided for @wmsError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка'**
  String get wmsError;

  /// No description provided for @wmsCreate.
  ///
  /// In ru, this message translates to:
  /// **'Создать'**
  String get wmsCreate;

  /// No description provided for @wmsSelectWarehouseFirst.
  ///
  /// In ru, this message translates to:
  /// **'Сначала выберите склад'**
  String get wmsSelectWarehouseFirst;

  /// No description provided for @wmsNewZone.
  ///
  /// In ru, this message translates to:
  /// **'Новая зона'**
  String get wmsNewZone;

  /// No description provided for @wmsZoneCode.
  ///
  /// In ru, this message translates to:
  /// **'Код зоны'**
  String get wmsZoneCode;

  /// No description provided for @wmsSelectZoneFirst.
  ///
  /// In ru, this message translates to:
  /// **'Сначала выберите зону'**
  String get wmsSelectZoneFirst;

  /// No description provided for @wmsGenerateCells.
  ///
  /// In ru, this message translates to:
  /// **'Генерация ячеек'**
  String get wmsGenerateCells;

  /// No description provided for @wmsRows.
  ///
  /// In ru, this message translates to:
  /// **'Ряды'**
  String get wmsRows;

  /// No description provided for @wmsRacks.
  ///
  /// In ru, this message translates to:
  /// **'Стеллажи'**
  String get wmsRacks;

  /// No description provided for @wmsLevels.
  ///
  /// In ru, this message translates to:
  /// **'Уровни'**
  String get wmsLevels;

  /// No description provided for @wmsBins.
  ///
  /// In ru, this message translates to:
  /// **'Ячейки'**
  String get wmsBins;

  /// No description provided for @wmsEditWarehouse.
  ///
  /// In ru, this message translates to:
  /// **'Редактировать склад'**
  String get wmsEditWarehouse;

  /// No description provided for @wmsAddress.
  ///
  /// In ru, this message translates to:
  /// **'Адрес'**
  String get wmsAddress;

  /// No description provided for @wmsDeleteWarehouseTitle.
  ///
  /// In ru, this message translates to:
  /// **'Удалить склад?'**
  String get wmsDeleteWarehouseTitle;

  /// No description provided for @wmsDeleteWarehouseConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Вы уверены, что хотите удалить склад \"{name}\"?'**
  String wmsDeleteWarehouseConfirm(String name);

  /// No description provided for @wmsCellStockTitle.
  ///
  /// In ru, this message translates to:
  /// **'Остатки по ячейкам'**
  String get wmsCellStockTitle;

  /// No description provided for @wmsPlace.
  ///
  /// In ru, this message translates to:
  /// **'Разместить'**
  String get wmsPlace;

  /// No description provided for @wmsPick.
  ///
  /// In ru, this message translates to:
  /// **'Отобрать'**
  String get wmsPick;

  /// No description provided for @wmsTransfer.
  ///
  /// In ru, this message translates to:
  /// **'Переместить'**
  String get wmsTransfer;

  /// No description provided for @wmsByCell.
  ///
  /// In ru, this message translates to:
  /// **'По ячейке'**
  String get wmsByCell;

  /// No description provided for @wmsByProduct.
  ///
  /// In ru, this message translates to:
  /// **'По товару'**
  String get wmsByProduct;

  /// No description provided for @wmsSearchCellHint.
  ///
  /// In ru, this message translates to:
  /// **'Введите ID или адрес ячейки...'**
  String get wmsSearchCellHint;

  /// No description provided for @wmsSearchProductHint.
  ///
  /// In ru, this message translates to:
  /// **'Введите ucode товара...'**
  String get wmsSearchProductHint;

  /// No description provided for @wmsCell.
  ///
  /// In ru, this message translates to:
  /// **'Ячейка'**
  String get wmsCell;

  /// No description provided for @wmsProductUcode.
  ///
  /// In ru, this message translates to:
  /// **'Код товара (ucode)'**
  String get wmsProductUcode;

  /// No description provided for @wmsFind.
  ///
  /// In ru, this message translates to:
  /// **'Найти'**
  String get wmsFind;

  /// No description provided for @wmsEnterCellIdToSearch.
  ///
  /// In ru, this message translates to:
  /// **'Введите ID ячейки для поиска остатков'**
  String get wmsEnterCellIdToSearch;

  /// No description provided for @wmsEnterUcodeToSearch.
  ///
  /// In ru, this message translates to:
  /// **'Введите ucode товара для поиска'**
  String get wmsEnterUcodeToSearch;

  /// No description provided for @wmsProductLabeled.
  ///
  /// In ru, this message translates to:
  /// **'Товар: {value}'**
  String wmsProductLabeled(String value);

  /// No description provided for @wmsCellLabeled.
  ///
  /// In ru, this message translates to:
  /// **'Ячейка: {value}'**
  String wmsCellLabeled(String value);

  /// No description provided for @wmsStockSummary.
  ///
  /// In ru, this message translates to:
  /// **'Кол-во: {qty}  |  Резерв: {reserved}  |  Доступно: {available}'**
  String wmsStockSummary(String qty, String reserved, String available);

  /// No description provided for @wmsBatchLabeled.
  ///
  /// In ru, this message translates to:
  /// **'Партия: {value}'**
  String wmsBatchLabeled(String value);

  /// No description provided for @wmsQuantityShort.
  ///
  /// In ru, this message translates to:
  /// **'Кол-во'**
  String get wmsQuantityShort;

  /// No description provided for @wmsReserved.
  ///
  /// In ru, this message translates to:
  /// **'Резерв'**
  String get wmsReserved;

  /// No description provided for @wmsAvailable.
  ///
  /// In ru, this message translates to:
  /// **'Доступно'**
  String get wmsAvailable;

  /// No description provided for @wmsBatch.
  ///
  /// In ru, this message translates to:
  /// **'Партия'**
  String get wmsBatch;

  /// No description provided for @wmsEnterNumericId.
  ///
  /// In ru, this message translates to:
  /// **'Введите числовой ID'**
  String get wmsEnterNumericId;

  /// No description provided for @wmsPlaceStockTitle.
  ///
  /// In ru, this message translates to:
  /// **'Разместить товар в ячейке'**
  String get wmsPlaceStockTitle;

  /// No description provided for @wmsCellId.
  ///
  /// In ru, this message translates to:
  /// **'ID ячейки'**
  String get wmsCellId;

  /// No description provided for @wmsProductUcodeField.
  ///
  /// In ru, this message translates to:
  /// **'ucode товара'**
  String get wmsProductUcodeField;

  /// No description provided for @wmsQuantity.
  ///
  /// In ru, this message translates to:
  /// **'Количество'**
  String get wmsQuantity;

  /// No description provided for @wmsBatchIdOptional.
  ///
  /// In ru, this message translates to:
  /// **'ID партии (необязательно)'**
  String get wmsBatchIdOptional;

  /// No description provided for @wmsFillRequiredNumericFields.
  ///
  /// In ru, this message translates to:
  /// **'Заполните обязательные поля (числовые значения)'**
  String get wmsFillRequiredNumericFields;

  /// No description provided for @wmsStockPlaced.
  ///
  /// In ru, this message translates to:
  /// **'Товар размещён в ячейке {cellId}'**
  String wmsStockPlaced(String cellId);

  /// No description provided for @wmsPlaceError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка размещения'**
  String get wmsPlaceError;

  /// No description provided for @wmsPickStockTitle.
  ///
  /// In ru, this message translates to:
  /// **'Отобрать товар из ячейки'**
  String get wmsPickStockTitle;

  /// No description provided for @wmsFillAllNumericFields.
  ///
  /// In ru, this message translates to:
  /// **'Заполните все поля (числовые значения)'**
  String get wmsFillAllNumericFields;

  /// No description provided for @wmsStockPicked.
  ///
  /// In ru, this message translates to:
  /// **'Товар отобран из ячейки {cellId}'**
  String wmsStockPicked(String cellId);

  /// No description provided for @wmsPickError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка отбора'**
  String get wmsPickError;

  /// No description provided for @wmsTransferStockTitle.
  ///
  /// In ru, this message translates to:
  /// **'Переместить товар'**
  String get wmsTransferStockTitle;

  /// No description provided for @wmsCellIdFrom.
  ///
  /// In ru, this message translates to:
  /// **'ID ячейки (откуда)'**
  String get wmsCellIdFrom;

  /// No description provided for @wmsCellIdTo.
  ///
  /// In ru, this message translates to:
  /// **'ID ячейки (куда)'**
  String get wmsCellIdTo;

  /// No description provided for @wmsStockTransferred.
  ///
  /// In ru, this message translates to:
  /// **'Товар перемещён из ячейки {from} в {to}'**
  String wmsStockTransferred(String from, String to);

  /// No description provided for @wmsTransferError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка перемещения'**
  String get wmsTransferError;

  /// No description provided for @wmsBatches.
  ///
  /// In ru, this message translates to:
  /// **'Партии'**
  String get wmsBatches;

  /// No description provided for @wmsBatchTrackingTitle.
  ///
  /// In ru, this message translates to:
  /// **'Партионный учёт'**
  String get wmsBatchTrackingTitle;

  /// No description provided for @wmsBatchTabAll.
  ///
  /// In ru, this message translates to:
  /// **'Все партии'**
  String get wmsBatchTabAll;

  /// No description provided for @wmsBatchTabExpiring.
  ///
  /// In ru, this message translates to:
  /// **'Истекающие'**
  String get wmsBatchTabExpiring;

  /// No description provided for @wmsBatchTabExpired.
  ///
  /// In ru, this message translates to:
  /// **'Просроченные'**
  String get wmsBatchTabExpired;

  /// No description provided for @wmsBatchTabQuarantine.
  ///
  /// In ru, this message translates to:
  /// **'Карантин'**
  String get wmsBatchTabQuarantine;

  /// No description provided for @wmsNoBatches.
  ///
  /// In ru, this message translates to:
  /// **'Нет партий'**
  String get wmsNoBatches;

  /// No description provided for @wmsNoExpiringBatches.
  ///
  /// In ru, this message translates to:
  /// **'Нет истекающих партий'**
  String get wmsNoExpiringBatches;

  /// No description provided for @wmsNoExpiredBatches.
  ///
  /// In ru, this message translates to:
  /// **'Нет просроченных партий'**
  String get wmsNoExpiredBatches;

  /// No description provided for @wmsNoQuarantinedBatches.
  ///
  /// In ru, this message translates to:
  /// **'Нет партий на карантине'**
  String get wmsNoQuarantinedBatches;

  /// No description provided for @wmsSearchByUcodeHint.
  ///
  /// In ru, this message translates to:
  /// **'Поиск по ucode товара...'**
  String get wmsSearchByUcodeHint;

  /// No description provided for @wmsNoNumber.
  ///
  /// In ru, this message translates to:
  /// **'Без номера'**
  String get wmsNoNumber;

  /// No description provided for @wmsBatchCardSummary.
  ///
  /// In ru, this message translates to:
  /// **'Товар: {ucode}  |  Срок: {expiry}  |  Кол-во: {qty}'**
  String wmsBatchCardSummary(String ucode, String expiry, String qty);

  /// No description provided for @wmsBatchNumber.
  ///
  /// In ru, this message translates to:
  /// **'Номер партии'**
  String get wmsBatchNumber;

  /// No description provided for @wmsProduct.
  ///
  /// In ru, this message translates to:
  /// **'Товар'**
  String get wmsProduct;

  /// No description provided for @wmsExpiryDate.
  ///
  /// In ru, this message translates to:
  /// **'Срок годности'**
  String get wmsExpiryDate;

  /// No description provided for @wmsStatus.
  ///
  /// In ru, this message translates to:
  /// **'Статус'**
  String get wmsStatus;

  /// No description provided for @wmsActions.
  ///
  /// In ru, this message translates to:
  /// **'Действия'**
  String get wmsActions;

  /// No description provided for @wmsQuarantine.
  ///
  /// In ru, this message translates to:
  /// **'Карантин'**
  String get wmsQuarantine;

  /// No description provided for @wmsApprove.
  ///
  /// In ru, this message translates to:
  /// **'Одобрить'**
  String get wmsApprove;

  /// No description provided for @wmsStatusQuarantine.
  ///
  /// In ru, this message translates to:
  /// **'Карантин'**
  String get wmsStatusQuarantine;

  /// No description provided for @wmsStatusExpired.
  ///
  /// In ru, this message translates to:
  /// **'Просрочено'**
  String get wmsStatusExpired;

  /// No description provided for @wmsStatusExpiring.
  ///
  /// In ru, this message translates to:
  /// **'Истекает'**
  String get wmsStatusExpiring;

  /// No description provided for @wmsStatusOk.
  ///
  /// In ru, this message translates to:
  /// **'ОК'**
  String get wmsStatusOk;

  /// No description provided for @wmsMoveToQuarantine.
  ///
  /// In ru, this message translates to:
  /// **'Поместить в карантин'**
  String get wmsMoveToQuarantine;

  /// No description provided for @wmsBatchQuarantined.
  ///
  /// In ru, this message translates to:
  /// **'Партия {number} помещена в карантин'**
  String wmsBatchQuarantined(String number);

  /// No description provided for @wmsBatchApproved.
  ///
  /// In ru, this message translates to:
  /// **'Партия {number} одобрена'**
  String wmsBatchApproved(String number);

  /// No description provided for @wmsSearchBatchesByProduct.
  ///
  /// In ru, this message translates to:
  /// **'Поиск партий по товару'**
  String get wmsSearchBatchesByProduct;

  /// No description provided for @wmsEnterProductCode.
  ///
  /// In ru, this message translates to:
  /// **'Введите код товара'**
  String get wmsEnterProductCode;

  /// No description provided for @wmsSerialTrackingTitle.
  ///
  /// In ru, this message translates to:
  /// **'Серийный учёт'**
  String get wmsSerialTrackingTitle;

  /// No description provided for @wmsScan.
  ///
  /// In ru, this message translates to:
  /// **'Сканировать'**
  String get wmsScan;

  /// No description provided for @wmsSearchBySerialHint.
  ///
  /// In ru, this message translates to:
  /// **'Поиск по серийному номеру...'**
  String get wmsSearchBySerialHint;

  /// No description provided for @wmsNothingFound.
  ///
  /// In ru, this message translates to:
  /// **'Ничего не найдено'**
  String get wmsNothingFound;

  /// No description provided for @wmsEnterSerialToSearch.
  ///
  /// In ru, this message translates to:
  /// **'Введите серийный номер для поиска'**
  String get wmsEnterSerialToSearch;

  /// No description provided for @wmsRegister.
  ///
  /// In ru, this message translates to:
  /// **'Зарегистрировать'**
  String get wmsRegister;

  /// No description provided for @wmsSelectSerial.
  ///
  /// In ru, this message translates to:
  /// **'Выберите серийный номер'**
  String get wmsSelectSerial;

  /// No description provided for @wmsSerialNumber.
  ///
  /// In ru, this message translates to:
  /// **'Серийный номер'**
  String get wmsSerialNumber;

  /// No description provided for @wmsLocation.
  ///
  /// In ru, this message translates to:
  /// **'Местоположение'**
  String get wmsLocation;

  /// No description provided for @wmsCellHash.
  ///
  /// In ru, this message translates to:
  /// **'Ячейка #{id}'**
  String wmsCellHash(String id);

  /// No description provided for @wmsDetails.
  ///
  /// In ru, this message translates to:
  /// **'Детали'**
  String get wmsDetails;

  /// No description provided for @wmsMarking.
  ///
  /// In ru, this message translates to:
  /// **'Маркировка'**
  String get wmsMarking;

  /// No description provided for @wmsWarrantyUntil.
  ///
  /// In ru, this message translates to:
  /// **'Гарантия до'**
  String get wmsWarrantyUntil;

  /// No description provided for @wmsNotes.
  ///
  /// In ru, this message translates to:
  /// **'Примечания'**
  String get wmsNotes;

  /// No description provided for @wmsMovementHistory.
  ///
  /// In ru, this message translates to:
  /// **'История движений'**
  String get wmsMovementHistory;

  /// No description provided for @wmsNoData.
  ///
  /// In ru, this message translates to:
  /// **'Нет данных'**
  String get wmsNoData;

  /// No description provided for @wmsSerialStatusInStock.
  ///
  /// In ru, this message translates to:
  /// **'На складе'**
  String get wmsSerialStatusInStock;

  /// No description provided for @wmsSerialStatusSold.
  ///
  /// In ru, this message translates to:
  /// **'Продан'**
  String get wmsSerialStatusSold;

  /// No description provided for @wmsSerialStatusReturned.
  ///
  /// In ru, this message translates to:
  /// **'Возвращён'**
  String get wmsSerialStatusReturned;

  /// No description provided for @wmsSerialStatusWrittenOff.
  ///
  /// In ru, this message translates to:
  /// **'Списан'**
  String get wmsSerialStatusWrittenOff;

  /// No description provided for @wmsSerialStatusUnknown.
  ///
  /// In ru, this message translates to:
  /// **'Неизвестно'**
  String get wmsSerialStatusUnknown;

  /// No description provided for @wmsScannerUseHardware.
  ///
  /// In ru, this message translates to:
  /// **'Сканер: используйте аппаратный сканер'**
  String get wmsScannerUseHardware;

  /// No description provided for @wmsRegisterSerialTitle.
  ///
  /// In ru, this message translates to:
  /// **'Регистрация серийного номера'**
  String get wmsRegisterSerialTitle;

  /// No description provided for @wmsSerialRegistered.
  ///
  /// In ru, this message translates to:
  /// **'Серийный номер зарегистрирован'**
  String get wmsSerialRegistered;

  /// No description provided for @wmsMarkingCodesTitle.
  ///
  /// In ru, this message translates to:
  /// **'Коды маркировки'**
  String get wmsMarkingCodesTitle;

  /// No description provided for @wmsMarkingAccept.
  ///
  /// In ru, this message translates to:
  /// **'Приёмка'**
  String get wmsMarkingAccept;

  /// No description provided for @wmsRefresh.
  ///
  /// In ru, this message translates to:
  /// **'Обновить'**
  String get wmsRefresh;

  /// No description provided for @wmsIsMptSettings.
  ///
  /// In ru, this message translates to:
  /// **'Настройки ИС МПТ'**
  String get wmsIsMptSettings;

  /// No description provided for @wmsMarkingAcceptTitle.
  ///
  /// In ru, this message translates to:
  /// **'Приёмка кодов маркировки'**
  String get wmsMarkingAcceptTitle;

  /// No description provided for @wmsSupplyIdOptional.
  ///
  /// In ru, this message translates to:
  /// **'ID поставки (необяз.)'**
  String get wmsSupplyIdOptional;

  /// No description provided for @wmsMarkingCodesPerLine.
  ///
  /// In ru, this message translates to:
  /// **'Коды маркировки (по одному на строку)'**
  String get wmsMarkingCodesPerLine;

  /// No description provided for @wmsAccept.
  ///
  /// In ru, this message translates to:
  /// **'Принять'**
  String get wmsAccept;

  /// No description provided for @wmsNoCodesEntered.
  ///
  /// In ru, this message translates to:
  /// **'Не введено ни одного кода'**
  String get wmsNoCodesEntered;

  /// No description provided for @wmsAcceptedLocally.
  ///
  /// In ru, this message translates to:
  /// **'Принято локально: {count} (ИС МПТ — отложено)'**
  String wmsAcceptedLocally(String count);

  /// No description provided for @wmsAccepted.
  ///
  /// In ru, this message translates to:
  /// **'Принято: {count}'**
  String wmsAccepted(String count);

  /// No description provided for @wmsAcceptError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка приёмки: {error}'**
  String wmsAcceptError(String error);

  /// No description provided for @wmsMarkingStatusResult.
  ///
  /// In ru, this message translates to:
  /// **'Статус КМ: {status}'**
  String wmsMarkingStatusResult(String status);

  /// No description provided for @wmsInCirculation.
  ///
  /// In ru, this message translates to:
  /// **'(в обороте)'**
  String get wmsInCirculation;

  /// No description provided for @wmsIsMptNoConnection.
  ///
  /// In ru, this message translates to:
  /// **'Нет связи с ИС МПТ — проверка отложена'**
  String get wmsIsMptNoConnection;

  /// No description provided for @wmsVerifyUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Проверка недоступна (ИС МПТ не настроена)'**
  String get wmsVerifyUnavailable;

  /// No description provided for @wmsVerifyError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка проверки: {error}'**
  String wmsVerifyError(String error);

  /// No description provided for @wmsNoMarkingCodes.
  ///
  /// In ru, this message translates to:
  /// **'Нет кодов маркировки'**
  String get wmsNoMarkingCodes;

  /// No description provided for @wmsVerifyStatus.
  ///
  /// In ru, this message translates to:
  /// **'Проверить статус (ИС МПТ)'**
  String get wmsVerifyStatus;

  /// No description provided for @wmsMarkingStatusReceived.
  ///
  /// In ru, this message translates to:
  /// **'Получен'**
  String get wmsMarkingStatusReceived;

  /// No description provided for @wmsMarkingStatusInStock.
  ///
  /// In ru, this message translates to:
  /// **'На складе'**
  String get wmsMarkingStatusInStock;

  /// No description provided for @wmsMarkingStatusSold.
  ///
  /// In ru, this message translates to:
  /// **'Продан'**
  String get wmsMarkingStatusSold;

  /// No description provided for @wmsMarkingStatusReturned.
  ///
  /// In ru, this message translates to:
  /// **'Возврат'**
  String get wmsMarkingStatusReturned;

  /// No description provided for @wmsMarkingStatusRetired.
  ///
  /// In ru, this message translates to:
  /// **'Списан'**
  String get wmsMarkingStatusRetired;

  /// No description provided for @wmsMarkingStatusBlocked.
  ///
  /// In ru, this message translates to:
  /// **'Заблокирован'**
  String get wmsMarkingStatusBlocked;

  /// No description provided for @wmsClaims.
  ///
  /// In ru, this message translates to:
  /// **'Рекламации'**
  String get wmsClaims;

  /// No description provided for @wmsClaimTabOpen.
  ///
  /// In ru, this message translates to:
  /// **'Открытые'**
  String get wmsClaimTabOpen;

  /// No description provided for @wmsClaimTabInProgress.
  ///
  /// In ru, this message translates to:
  /// **'В работе'**
  String get wmsClaimTabInProgress;

  /// No description provided for @wmsClaimTabResolved.
  ///
  /// In ru, this message translates to:
  /// **'Решённые'**
  String get wmsClaimTabResolved;

  /// No description provided for @wmsNoOpenClaims.
  ///
  /// In ru, this message translates to:
  /// **'Нет открытых рекламаций'**
  String get wmsNoOpenClaims;

  /// No description provided for @wmsNoInProgressClaims.
  ///
  /// In ru, this message translates to:
  /// **'Нет рекламаций в работе'**
  String get wmsNoInProgressClaims;

  /// No description provided for @wmsNoResolvedClaims.
  ///
  /// In ru, this message translates to:
  /// **'Нет решённых рекламаций'**
  String get wmsNoResolvedClaims;

  /// No description provided for @wmsNewClaim.
  ///
  /// In ru, this message translates to:
  /// **'Новая рекламация'**
  String get wmsNewClaim;

  /// No description provided for @wmsNumber.
  ///
  /// In ru, this message translates to:
  /// **'Номер'**
  String get wmsNumber;

  /// No description provided for @wmsType.
  ///
  /// In ru, this message translates to:
  /// **'Тип'**
  String get wmsType;

  /// No description provided for @wmsSeverity.
  ///
  /// In ru, this message translates to:
  /// **'Серьёзность'**
  String get wmsSeverity;

  /// No description provided for @wmsDate.
  ///
  /// In ru, this message translates to:
  /// **'Дата'**
  String get wmsDate;

  /// No description provided for @wmsSeverityLow.
  ///
  /// In ru, this message translates to:
  /// **'Низкая'**
  String get wmsSeverityLow;

  /// No description provided for @wmsSeverityMedium.
  ///
  /// In ru, this message translates to:
  /// **'Средняя'**
  String get wmsSeverityMedium;

  /// No description provided for @wmsSeverityHigh.
  ///
  /// In ru, this message translates to:
  /// **'Высокая'**
  String get wmsSeverityHigh;

  /// No description provided for @wmsSeverityCritical.
  ///
  /// In ru, this message translates to:
  /// **'Критическая'**
  String get wmsSeverityCritical;

  /// No description provided for @wmsClaimTypeDefect.
  ///
  /// In ru, this message translates to:
  /// **'Брак'**
  String get wmsClaimTypeDefect;

  /// No description provided for @wmsClaimTypeMissort.
  ///
  /// In ru, this message translates to:
  /// **'Пересортица'**
  String get wmsClaimTypeMissort;

  /// No description provided for @wmsClaimTypeShortage.
  ///
  /// In ru, this message translates to:
  /// **'Недостача'**
  String get wmsClaimTypeShortage;

  /// No description provided for @wmsClaimTypeDamage.
  ///
  /// In ru, this message translates to:
  /// **'Повреждение'**
  String get wmsClaimTypeDamage;

  /// No description provided for @wmsClaimTypeOther.
  ///
  /// In ru, this message translates to:
  /// **'Другое'**
  String get wmsClaimTypeOther;

  /// No description provided for @wmsProblemDescription.
  ///
  /// In ru, this message translates to:
  /// **'Описание проблемы'**
  String get wmsProblemDescription;

  /// No description provided for @wmsClaimCreated.
  ///
  /// In ru, this message translates to:
  /// **'Рекламация создана'**
  String get wmsClaimCreated;

  /// No description provided for @wmsClaimTitle.
  ///
  /// In ru, this message translates to:
  /// **'Рекламация {number}'**
  String wmsClaimTitle(String number);

  /// No description provided for @wmsTypeLabeled.
  ///
  /// In ru, this message translates to:
  /// **'Тип: {value}'**
  String wmsTypeLabeled(String value);

  /// No description provided for @wmsSeverityLabeled.
  ///
  /// In ru, this message translates to:
  /// **'Серьёзность: {value}'**
  String wmsSeverityLabeled(String value);

  /// No description provided for @wmsDateLabeled.
  ///
  /// In ru, this message translates to:
  /// **'Дата: {value}'**
  String wmsDateLabeled(String value);

  /// No description provided for @wmsProblemDescriptionLabel.
  ///
  /// In ru, this message translates to:
  /// **'Описание проблемы:'**
  String get wmsProblemDescriptionLabel;

  /// No description provided for @wmsNoDescription.
  ///
  /// In ru, this message translates to:
  /// **'Нет описания'**
  String get wmsNoDescription;

  /// No description provided for @wmsResolutionLabel.
  ///
  /// In ru, this message translates to:
  /// **'Решение:'**
  String get wmsResolutionLabel;

  /// No description provided for @wmsNotSpecified.
  ///
  /// In ru, this message translates to:
  /// **'Не указано'**
  String get wmsNotSpecified;

  /// No description provided for @wmsHistoryLabel.
  ///
  /// In ru, this message translates to:
  /// **'История:'**
  String get wmsHistoryLabel;

  /// No description provided for @wmsNoRecords.
  ///
  /// In ru, this message translates to:
  /// **'Нет записей'**
  String get wmsNoRecords;

  /// No description provided for @wmsResolve.
  ///
  /// In ru, this message translates to:
  /// **'Решить'**
  String get wmsResolve;

  /// No description provided for @wmsResolveClaimTitle.
  ///
  /// In ru, this message translates to:
  /// **'Решить рекламацию'**
  String get wmsResolveClaimTitle;

  /// No description provided for @wmsResolutionNotes.
  ///
  /// In ru, this message translates to:
  /// **'Заметки по решению'**
  String get wmsResolutionNotes;

  /// No description provided for @wmsClaimResolved.
  ///
  /// In ru, this message translates to:
  /// **'Рекламация решена'**
  String get wmsClaimResolved;

  /// No description provided for @setUserManagementTitle.
  ///
  /// In ru, this message translates to:
  /// **'Пользователи и доступ'**
  String get setUserManagementTitle;

  /// No description provided for @setUsersTitle.
  ///
  /// In ru, this message translates to:
  /// **'Пользователи'**
  String get setUsersTitle;

  /// No description provided for @setUsersSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Управление доступом'**
  String get setUsersSubtitle;

  /// No description provided for @authSettingsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Вход и сеанс'**
  String get authSettingsTitle;

  /// No description provided for @authSettingsSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Вход без кассира и срок сеанса'**
  String get authSettingsSubtitle;

  /// No description provided for @authSettingsWalkUpTitle.
  ///
  /// In ru, this message translates to:
  /// **'Вход без выбора кассира'**
  String get authSettingsWalkUpTitle;

  /// No description provided for @authSettingsWalkUpSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Один PIN пускает без имени. Небезопасно при нескольких кассирах: по умолчанию выключено.'**
  String get authSettingsWalkUpSubtitle;

  /// No description provided for @authSettingsSessionTitle.
  ///
  /// In ru, this message translates to:
  /// **'Срок сеанса'**
  String get authSettingsSessionTitle;

  /// No description provided for @authSettingsSessionSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Сколько минут кассир остаётся в сеансе без действий. Меняется сразу, без перезапуска кассы.'**
  String get authSettingsSessionSubtitle;

  /// No description provided for @authSettingsSessionMinutesLabel.
  ///
  /// In ru, this message translates to:
  /// **'Минут'**
  String get authSettingsSessionMinutesLabel;

  /// No description provided for @authSettingsSaved.
  ///
  /// In ru, this message translates to:
  /// **'Сохранено'**
  String get authSettingsSaved;

  /// No description provided for @authSettingsInvalidMinutes.
  ///
  /// In ru, this message translates to:
  /// **'Введите целое число минут от 1 до 1440'**
  String get authSettingsInvalidMinutes;

  /// No description provided for @sessionsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Активные сеансы'**
  String get sessionsTitle;

  /// No description provided for @sessionsSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Кто сейчас в кассе, отзыв по кнопке'**
  String get sessionsSubtitle;

  /// No description provided for @sessionsEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Сейчас никто не вошёл в кассу'**
  String get sessionsEmpty;

  /// No description provided for @sessionsTerminalLabel.
  ///
  /// In ru, this message translates to:
  /// **'Терминал №{id}'**
  String sessionsTerminalLabel(String id);

  /// No description provided for @sessionsTimes.
  ///
  /// In ru, this message translates to:
  /// **'Вошёл {issued} · истекает {expires}'**
  String sessionsTimes(String issued, String expires);

  /// No description provided for @sessionsRevoke.
  ///
  /// In ru, this message translates to:
  /// **'Завершить'**
  String get sessionsRevoke;

  /// No description provided for @sessionsRevokeConfirmTitle.
  ///
  /// In ru, this message translates to:
  /// **'Завершить сеанс?'**
  String get sessionsRevokeConfirmTitle;

  /// No description provided for @sessionsRevokeConfirmBody.
  ///
  /// In ru, this message translates to:
  /// **'«{name}» будет выведен из кассы немедленно.'**
  String sessionsRevokeConfirmBody(String name);

  /// No description provided for @sessionsRevoked.
  ///
  /// In ru, this message translates to:
  /// **'Сеанс «{name}» завершён'**
  String sessionsRevoked(String name);

  /// No description provided for @sessionsRevokeError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось завершить сеанс: {error}'**
  String sessionsRevokeError(String error);

  /// No description provided for @setUsersEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Нет пользователей'**
  String get setUsersEmpty;

  /// No description provided for @setAddUser.
  ///
  /// In ru, this message translates to:
  /// **'Добавить пользователя'**
  String get setAddUser;

  /// No description provided for @setUserNumber.
  ///
  /// In ru, this message translates to:
  /// **'Пользователь №{id}'**
  String setUserNumber(String id);

  /// No description provided for @setUserActive.
  ///
  /// In ru, this message translates to:
  /// **'Активен'**
  String get setUserActive;

  /// No description provided for @setUsersLoadError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка: {error}'**
  String setUsersLoadError(String error);

  /// No description provided for @setNewUser.
  ///
  /// In ru, this message translates to:
  /// **'Новый пользователь'**
  String get setNewUser;

  /// No description provided for @setEditUser.
  ///
  /// In ru, this message translates to:
  /// **'Редактирование'**
  String get setEditUser;

  /// No description provided for @setUserTabProfile.
  ///
  /// In ru, this message translates to:
  /// **'Профиль'**
  String get setUserTabProfile;

  /// No description provided for @setUserTabPermissions.
  ///
  /// In ru, this message translates to:
  /// **'Права доступа'**
  String get setUserTabPermissions;

  /// No description provided for @setUserName.
  ///
  /// In ru, this message translates to:
  /// **'Имя'**
  String get setUserName;

  /// No description provided for @setUserNameRequired.
  ///
  /// In ru, this message translates to:
  /// **'Введите имя'**
  String get setUserNameRequired;

  /// No description provided for @setUserPinLabel.
  ///
  /// In ru, this message translates to:
  /// **'PIN (4-6 цифр)'**
  String get setUserPinLabel;

  /// No description provided for @setUserPinRequired.
  ///
  /// In ru, this message translates to:
  /// **'Введите PIN'**
  String get setUserPinRequired;

  /// No description provided for @setUserPinMin.
  ///
  /// In ru, this message translates to:
  /// **'Минимум 4 цифры'**
  String get setUserPinMin;

  /// No description provided for @setUserPinRange.
  ///
  /// In ru, this message translates to:
  /// **'PIN должен быть 4-6 цифр'**
  String get setUserPinRange;

  /// No description provided for @setUserRole.
  ///
  /// In ru, this message translates to:
  /// **'Роль'**
  String get setUserRole;

  /// No description provided for @setRoleOwner.
  ///
  /// In ru, this message translates to:
  /// **'Владелец'**
  String get setRoleOwner;

  /// No description provided for @setRoleAdministrator.
  ///
  /// In ru, this message translates to:
  /// **'Администратор'**
  String get setRoleAdministrator;

  /// No description provided for @setRoleUser.
  ///
  /// In ru, this message translates to:
  /// **'Пользователь'**
  String get setRoleUser;

  /// No description provided for @setRoleCashier.
  ///
  /// In ru, this message translates to:
  /// **'Кассир'**
  String get setRoleCashier;

  /// No description provided for @setUserActiveDesc.
  ///
  /// In ru, this message translates to:
  /// **'Пользователь может входить в систему'**
  String get setUserActiveDesc;

  /// No description provided for @setUserBlockedDesc.
  ///
  /// In ru, this message translates to:
  /// **'Доступ заблокирован'**
  String get setUserBlockedDesc;

  /// No description provided for @setUserOwnerFullAccess.
  ///
  /// In ru, this message translates to:
  /// **'Владелец имеет полный доступ'**
  String get setUserOwnerFullAccess;

  /// No description provided for @setUserSelectAll.
  ///
  /// In ru, this message translates to:
  /// **'Выбрать все'**
  String get setUserSelectAll;

  /// No description provided for @setUserDeselectAll.
  ///
  /// In ru, this message translates to:
  /// **'Снять все'**
  String get setUserDeselectAll;

  /// No description provided for @setDeleteUserTitle.
  ///
  /// In ru, this message translates to:
  /// **'Удалить пользователя?'**
  String get setDeleteUserTitle;

  /// No description provided for @setDeleteUserConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Пользователь «{name}» будет удалён. Это действие нельзя отменить.'**
  String setDeleteUserConfirm(String name);

  /// No description provided for @setDeleteUserError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось удалить пользователя: {error}'**
  String setDeleteUserError(String error);

  /// No description provided for @setUserNoEncryptionKey.
  ///
  /// In ru, this message translates to:
  /// **'Не настроен ключ шифрования. Завершите начальную настройку POS.'**
  String get setUserNoEncryptionKey;

  /// No description provided for @setUserPinEncryptFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось зашифровать PIN'**
  String get setUserPinEncryptFailed;

  /// No description provided for @setWmsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Настройки WMS'**
  String get setWmsTitle;

  /// No description provided for @setWmsModules.
  ///
  /// In ru, this message translates to:
  /// **'Модули WMS'**
  String get setWmsModules;

  /// No description provided for @setWmsCellStorage.
  ///
  /// In ru, this message translates to:
  /// **'Ячеечное хранение'**
  String get setWmsCellStorage;

  /// No description provided for @setWmsCellStorageDesc.
  ///
  /// In ru, this message translates to:
  /// **'Адресное хранение товаров по зонам и ячейкам'**
  String get setWmsCellStorageDesc;

  /// No description provided for @setWmsBatchTracking.
  ///
  /// In ru, this message translates to:
  /// **'Партионный учёт'**
  String get setWmsBatchTracking;

  /// No description provided for @setWmsBatchTrackingDesc.
  ///
  /// In ru, this message translates to:
  /// **'Учёт товаров по партиям с отслеживанием поставок'**
  String get setWmsBatchTrackingDesc;

  /// No description provided for @setWmsSerialTracking.
  ///
  /// In ru, this message translates to:
  /// **'Серийный учёт'**
  String get setWmsSerialTracking;

  /// No description provided for @setWmsSerialTrackingDesc.
  ///
  /// In ru, this message translates to:
  /// **'Поштучный учёт по уникальным серийным номерам'**
  String get setWmsSerialTrackingDesc;

  /// No description provided for @setWmsExpiryControl.
  ///
  /// In ru, this message translates to:
  /// **'Контроль сроков годности'**
  String get setWmsExpiryControl;

  /// No description provided for @setWmsExpiryControlDesc.
  ///
  /// In ru, this message translates to:
  /// **'Предупреждения об истечении и автоматический FEFO-подбор'**
  String get setWmsExpiryControlDesc;

  /// No description provided for @setWmsMarking.
  ///
  /// In ru, this message translates to:
  /// **'Маркировка'**
  String get setWmsMarking;

  /// No description provided for @setWmsMarkingDesc.
  ///
  /// In ru, this message translates to:
  /// **'Поддержка обязательных кодов маркировки (DataMatrix, GS1)'**
  String get setWmsMarkingDesc;

  /// No description provided for @setWmsWarranty.
  ///
  /// In ru, this message translates to:
  /// **'Гарантийный учёт'**
  String get setWmsWarranty;

  /// No description provided for @setWmsWarrantyDesc.
  ///
  /// In ru, this message translates to:
  /// **'Отслеживание гарантийных сроков по серийным номерам'**
  String get setWmsWarrantyDesc;

  /// No description provided for @setWmsPickingStrategy.
  ///
  /// In ru, this message translates to:
  /// **'Стратегия подбора'**
  String get setWmsPickingStrategy;

  /// No description provided for @setWmsPickingStrategyDesc.
  ///
  /// In ru, this message translates to:
  /// **'Определяет порядок отгрузки товаров со склада'**
  String get setWmsPickingStrategyDesc;

  /// No description provided for @setWmsStrategy.
  ///
  /// In ru, this message translates to:
  /// **'Стратегия'**
  String get setWmsStrategy;

  /// No description provided for @setWmsStrategyFefo.
  ///
  /// In ru, this message translates to:
  /// **'FEFO — первый истекает, первый уходит'**
  String get setWmsStrategyFefo;

  /// No description provided for @setWmsStrategyFifo.
  ///
  /// In ru, this message translates to:
  /// **'FIFO — первый пришёл, первый ушёл'**
  String get setWmsStrategyFifo;

  /// No description provided for @setWmsStrategyLifo.
  ///
  /// In ru, this message translates to:
  /// **'LIFO — последний пришёл, первый ушёл'**
  String get setWmsStrategyLifo;

  /// No description provided for @setWmsCostMethod.
  ///
  /// In ru, this message translates to:
  /// **'Метод расчёта себестоимости'**
  String get setWmsCostMethod;

  /// No description provided for @setWmsCostMethodDesc.
  ///
  /// In ru, this message translates to:
  /// **'Метод списания себестоимости при продаже'**
  String get setWmsCostMethodDesc;

  /// No description provided for @setWmsMethod.
  ///
  /// In ru, this message translates to:
  /// **'Метод'**
  String get setWmsMethod;

  /// No description provided for @setWmsCostFifo.
  ///
  /// In ru, this message translates to:
  /// **'FIFO — по порядку поступления'**
  String get setWmsCostFifo;

  /// No description provided for @setWmsCostLifo.
  ///
  /// In ru, this message translates to:
  /// **'LIFO — по обратному порядку'**
  String get setWmsCostLifo;

  /// No description provided for @setWmsCostAvg.
  ///
  /// In ru, this message translates to:
  /// **'Средневзвешенная стоимость'**
  String get setWmsCostAvg;

  /// No description provided for @setWmsExpiryWarnDesc.
  ///
  /// In ru, this message translates to:
  /// **'За сколько дней до истечения предупреждать'**
  String get setWmsExpiryWarnDesc;

  /// No description provided for @setWmsDaysShort.
  ///
  /// In ru, this message translates to:
  /// **'{days} дн.'**
  String setWmsDaysShort(int days);

  /// No description provided for @setWmsAbcAnalysis.
  ///
  /// In ru, this message translates to:
  /// **'ABC-анализ'**
  String get setWmsAbcAnalysis;

  /// No description provided for @setWmsAbcDesc.
  ///
  /// In ru, this message translates to:
  /// **'Пороги классификации товаров по обороту'**
  String get setWmsAbcDesc;

  /// No description provided for @setWmsAbcCategoryA.
  ///
  /// In ru, this message translates to:
  /// **'Категория A (высокий оборот)'**
  String get setWmsAbcCategoryA;

  /// No description provided for @setWmsAbcCategoryB.
  ///
  /// In ru, this message translates to:
  /// **'Категория B (средний оборот)'**
  String get setWmsAbcCategoryB;

  /// No description provided for @setWmsAbcCategoryC.
  ///
  /// In ru, this message translates to:
  /// **'Категория C (низкий оборот)'**
  String get setWmsAbcCategoryC;

  /// No description provided for @setWmsSaved.
  ///
  /// In ru, this message translates to:
  /// **'Настройки WMS сохранены'**
  String get setWmsSaved;

  /// No description provided for @setWmsSaveError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось сохранить настройки WMS'**
  String get setWmsSaveError;

  /// No description provided for @setSalesPolicy.
  ///
  /// In ru, this message translates to:
  /// **'Политика продаж'**
  String get setSalesPolicy;

  /// No description provided for @setSalesPolicyDesc.
  ///
  /// In ru, this message translates to:
  /// **'Контроль остатков при продаже'**
  String get setSalesPolicyDesc;

  /// No description provided for @setBlockOversell.
  ///
  /// In ru, this message translates to:
  /// **'Запрет продажи при недостатке остатка'**
  String get setBlockOversell;

  /// No description provided for @setBlockOversellDesc.
  ///
  /// In ru, this message translates to:
  /// **'Не завершать продажу, если количество в чеке превышает остаток (защита от отрицательного остатка)'**
  String get setBlockOversellDesc;

  /// No description provided for @setScreenTouch.
  ///
  /// In ru, this message translates to:
  /// **'Экран и тачскрин'**
  String get setScreenTouch;

  /// No description provided for @setScreenTouchDesc.
  ///
  /// In ru, this message translates to:
  /// **'Удобство на сенсорном экране'**
  String get setScreenTouchDesc;

  /// No description provided for @setScrollAssist.
  ///
  /// In ru, this message translates to:
  /// **'Кнопки прокрутки на сенсорном экране'**
  String get setScrollAssist;

  /// No description provided for @setScrollAssistDesc.
  ///
  /// In ru, this message translates to:
  /// **'Экранные кнопки ▲/▼ для прокрутки длинных списков (каталог, чек, отчёты, склад) на тачскрине'**
  String get setScrollAssistDesc;

  /// No description provided for @setDemoData.
  ///
  /// In ru, this message translates to:
  /// **'Демо данные'**
  String get setDemoData;

  /// No description provided for @setDemoDataSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'12 месяцев продаж'**
  String get setDemoDataSubtitle;

  /// No description provided for @setDemoDataDialogContent.
  ///
  /// In ru, this message translates to:
  /// **'Загрузить демо данные для всех режимов:\n• Розница: ~6000 продаж, поставки, возвраты\n• Ресторан: 15 столов, 29 блюд с калькуляцией, заказы\n• Сервис: услуги, расходники, заказ-наряды\n\nИли очистить все данные для чистого старта.'**
  String get setDemoDataDialogContent;

  /// No description provided for @setDemoClearAll.
  ///
  /// In ru, this message translates to:
  /// **'Очистить всё'**
  String get setDemoClearAll;

  /// No description provided for @setDemoLoad.
  ///
  /// In ru, this message translates to:
  /// **'Загрузить демо'**
  String get setDemoLoad;

  /// No description provided for @setDemoGenerating.
  ///
  /// In ru, this message translates to:
  /// **'Генерация демо данных...'**
  String get setDemoGenerating;

  /// No description provided for @setDemoLoadedTitle.
  ///
  /// In ru, this message translates to:
  /// **'Демо данные загружены'**
  String get setDemoLoadedTitle;

  /// No description provided for @setDemoAlreadyExists.
  ///
  /// In ru, this message translates to:
  /// **'Данные уже существуют. Сначала нажмите «Очистить всё».'**
  String get setDemoAlreadyExists;

  /// No description provided for @setClearDataTitle.
  ///
  /// In ru, this message translates to:
  /// **'Очистка данных'**
  String get setClearDataTitle;

  /// No description provided for @setClearDataContent.
  ///
  /// In ru, this message translates to:
  /// **'ВСЕ данные будут удалены:\n• Продажи, возвраты, платежи\n• Товары, категории, цены\n• Контрагенты, поставки\n• Заказы, смены, кассовые операции\n• Ресторанные столы, заказы\n• Сервисные заказы\n\nНастройки POS и пользователи сохранятся.\nЭто действие необратимо!'**
  String get setClearDataContent;

  /// No description provided for @setClearDeleteAll.
  ///
  /// In ru, this message translates to:
  /// **'Удалить всё'**
  String get setClearDeleteAll;

  /// No description provided for @setClearInProgress.
  ///
  /// In ru, this message translates to:
  /// **'Очистка данных...'**
  String get setClearInProgress;

  /// No description provided for @setClearDone.
  ///
  /// In ru, this message translates to:
  /// **'Все данные очищены'**
  String get setClearDone;

  /// No description provided for @setGenericError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка: {error}'**
  String setGenericError(String error);

  /// No description provided for @setCorrectionTitle.
  ///
  /// In ru, this message translates to:
  /// **'Чек коррекции'**
  String get setCorrectionTitle;

  /// No description provided for @setCorrectionIntro.
  ///
  /// In ru, this message translates to:
  /// **'Чек коррекции исправляет ранее пробитую или не пробитую сумму. Укажите причину и сумму. Если оператор не поддерживает коррекцию — это будет показано честно.'**
  String get setCorrectionIntro;

  /// No description provided for @setCorrectionReasonLabel.
  ///
  /// In ru, this message translates to:
  /// **'Причина коррекции'**
  String get setCorrectionReasonLabel;

  /// No description provided for @setCorrectionReasonHint.
  ///
  /// In ru, this message translates to:
  /// **'напр. самостоятельная корректировка'**
  String get setCorrectionReasonHint;

  /// No description provided for @setCorrectionAmountLabel.
  ///
  /// In ru, this message translates to:
  /// **'Сумма коррекции, {currency}'**
  String setCorrectionAmountLabel(String currency);

  /// No description provided for @setCorrectionPaymentLabel.
  ///
  /// In ru, this message translates to:
  /// **'Способ оплаты'**
  String get setCorrectionPaymentLabel;

  /// No description provided for @setCorrectionCash.
  ///
  /// In ru, this message translates to:
  /// **'Наличные'**
  String get setCorrectionCash;

  /// No description provided for @setCorrectionCard.
  ///
  /// In ru, this message translates to:
  /// **'Карта'**
  String get setCorrectionCard;

  /// No description provided for @setCorrectionSubmit.
  ///
  /// In ru, this message translates to:
  /// **'Отправить чек коррекции'**
  String get setCorrectionSubmit;

  /// No description provided for @setCorrectionDefaultName.
  ///
  /// In ru, this message translates to:
  /// **'Коррекция'**
  String get setCorrectionDefaultName;

  /// No description provided for @setCorrectionInvalidAmount.
  ///
  /// In ru, this message translates to:
  /// **'Введите корректную сумму коррекции (> 0)'**
  String get setCorrectionInvalidAmount;

  /// No description provided for @setCorrectionQueued.
  ///
  /// In ru, this message translates to:
  /// **'Чек коррекции поставлен в очередь (offline)'**
  String get setCorrectionQueued;

  /// No description provided for @setCorrectionSent.
  ///
  /// In ru, this message translates to:
  /// **'Чек коррекции отправлен'**
  String get setCorrectionSent;

  /// No description provided for @setCorrectionUnsupported.
  ///
  /// In ru, this message translates to:
  /// **'Чек коррекции не поддерживается текущим оператором'**
  String get setCorrectionUnsupported;

  /// No description provided for @setCorrectionNotConfigured.
  ///
  /// In ru, this message translates to:
  /// **'Фискализация не настроена'**
  String get setCorrectionNotConfigured;

  /// No description provided for @setCorrectionError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка чека коррекции'**
  String get setCorrectionError;

  /// No description provided for @setFiscalConnection.
  ///
  /// In ru, this message translates to:
  /// **'Подключение'**
  String get setFiscalConnection;

  /// No description provided for @setFiscalTestMode.
  ///
  /// In ru, this message translates to:
  /// **'Тестовый режим'**
  String get setFiscalTestMode;

  /// No description provided for @setFiscalLogin.
  ///
  /// In ru, this message translates to:
  /// **'Логин'**
  String get setFiscalLogin;

  /// No description provided for @setFiscalLoginHint.
  ///
  /// In ru, this message translates to:
  /// **'email / телефон'**
  String get setFiscalLoginHint;

  /// No description provided for @setFiscalPassword.
  ///
  /// In ru, this message translates to:
  /// **'Пароль'**
  String get setFiscalPassword;

  /// No description provided for @setFiscalCashboxSerial.
  ///
  /// In ru, this message translates to:
  /// **'ЗНМ (серийный номер кассы)'**
  String get setFiscalCashboxSerial;

  /// No description provided for @setFiscalCashboxSerialHint.
  ///
  /// In ru, this message translates to:
  /// **'напр. SWK00033717'**
  String get setFiscalCashboxSerialHint;

  /// No description provided for @setFiscalRnm.
  ///
  /// In ru, this message translates to:
  /// **'РНМ (рег. номер машины)'**
  String get setFiscalRnm;

  /// No description provided for @setFiscalKeyPath.
  ///
  /// In ru, this message translates to:
  /// **'Путь к ключу/сертификату'**
  String get setFiscalKeyPath;

  /// No description provided for @setFiscalOfflineModule.
  ///
  /// In ru, this message translates to:
  /// **'Адрес offline-модуля'**
  String get setFiscalOfflineModule;

  /// No description provided for @setFiscalVatRate.
  ///
  /// In ru, this message translates to:
  /// **'Ставка НДС, %'**
  String get setFiscalVatRate;

  /// No description provided for @dishTabRecipe.
  ///
  /// In ru, this message translates to:
  /// **'Рецептура'**
  String get dishTabRecipe;

  /// No description provided for @dishTabCosting.
  ///
  /// In ru, this message translates to:
  /// **'Себестоимость'**
  String get dishTabCosting;

  /// No description provided for @dishTabYield.
  ///
  /// In ru, this message translates to:
  /// **'Выход и КБЖУ'**
  String get dishTabYield;

  /// No description provided for @dishVersions.
  ///
  /// In ru, this message translates to:
  /// **'Версии'**
  String get dishVersions;

  /// No description provided for @dishCostLabel.
  ///
  /// In ru, this message translates to:
  /// **'Себестоимость'**
  String get dishCostLabel;

  /// No description provided for @dishPriceLabel.
  ///
  /// In ru, this message translates to:
  /// **'Цена'**
  String get dishPriceLabel;

  /// No description provided for @dishProfitLabel.
  ///
  /// In ru, this message translates to:
  /// **'Прибыль'**
  String get dishProfitLabel;

  /// No description provided for @dishMarkupLabel.
  ///
  /// In ru, this message translates to:
  /// **'Наценка'**
  String get dishMarkupLabel;

  /// No description provided for @dishNoIngredients.
  ///
  /// In ru, this message translates to:
  /// **'Нет ингредиентов'**
  String get dishNoIngredients;

  /// No description provided for @dishNoIngredientsHint.
  ///
  /// In ru, this message translates to:
  /// **'Добавьте ингредиенты для расчёта рецептуры'**
  String get dishNoIngredientsHint;

  /// No description provided for @dishAddIngredient.
  ///
  /// In ru, this message translates to:
  /// **'Добавить ингредиент'**
  String get dishAddIngredient;

  /// No description provided for @dishColIngredient.
  ///
  /// In ru, this message translates to:
  /// **'Ингредиент'**
  String get dishColIngredient;

  /// No description provided for @dishColGross.
  ///
  /// In ru, this message translates to:
  /// **'Брутто'**
  String get dishColGross;

  /// No description provided for @dishColColdLoss.
  ///
  /// In ru, this message translates to:
  /// **'Пот.обр.%'**
  String get dishColColdLoss;

  /// No description provided for @dishColNet.
  ///
  /// In ru, this message translates to:
  /// **'Нетто'**
  String get dishColNet;

  /// No description provided for @dishColHotLoss.
  ///
  /// In ru, this message translates to:
  /// **'Пот.т/о%'**
  String get dishColHotLoss;

  /// No description provided for @dishColYield.
  ///
  /// In ru, this message translates to:
  /// **'Выход'**
  String get dishColYield;

  /// No description provided for @dishColCost.
  ///
  /// In ru, this message translates to:
  /// **'Стоим.'**
  String get dishColCost;

  /// No description provided for @dishDeleteIngredient.
  ///
  /// In ru, this message translates to:
  /// **'Удалить ингредиент'**
  String get dishDeleteIngredient;

  /// No description provided for @dishTotal.
  ///
  /// In ru, this message translates to:
  /// **'Итого'**
  String get dishTotal;

  /// No description provided for @dishDeleteIngredientTitle.
  ///
  /// In ru, this message translates to:
  /// **'Удалить ингредиент?'**
  String get dishDeleteIngredientTitle;

  /// No description provided for @dishDeleteIngredientConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Удалить \"{name}\" из рецептуры?'**
  String dishDeleteIngredientConfirm(String name);

  /// No description provided for @dishSearchIngredientHint.
  ///
  /// In ru, this message translates to:
  /// **'Поиск ингредиента по названию или штрих-коду...'**
  String get dishSearchIngredientHint;

  /// No description provided for @dishCodeOnly.
  ///
  /// In ru, this message translates to:
  /// **'Код: {code}'**
  String dishCodeOnly(int code);

  /// No description provided for @dishCodeWithBarcode.
  ///
  /// In ru, this message translates to:
  /// **'Код: {code}  |  Штрих-код: {barcode}'**
  String dishCodeWithBarcode(int code, int barcode);

  /// No description provided for @dishAddTitle.
  ///
  /// In ru, this message translates to:
  /// **'Добавить: {name}'**
  String dishAddTitle(String name);

  /// No description provided for @dishGrossQty.
  ///
  /// In ru, this message translates to:
  /// **'Брутто (кол-во)'**
  String get dishGrossQty;

  /// No description provided for @dishColdLossLabel.
  ///
  /// In ru, this message translates to:
  /// **'Потери обработки, %'**
  String get dishColdLossLabel;

  /// No description provided for @dishHotLossLabel.
  ///
  /// In ru, this message translates to:
  /// **'Потери тепл. обработки, %'**
  String get dishHotLossLabel;

  /// No description provided for @dishSeasonCoefficient.
  ///
  /// In ru, this message translates to:
  /// **'Сезонный коэффициент'**
  String get dishSeasonCoefficient;

  /// No description provided for @dishSeasonStandard.
  ///
  /// In ru, this message translates to:
  /// **'Стандарт (x1.0)'**
  String get dishSeasonStandard;

  /// No description provided for @dishSeasonWinter.
  ///
  /// In ru, this message translates to:
  /// **'Зима (+15%) (x1.15)'**
  String get dishSeasonWinter;

  /// No description provided for @dishSeasonSummer.
  ///
  /// In ru, this message translates to:
  /// **'Лето (-5%) (x0.95)'**
  String get dishSeasonSummer;

  /// No description provided for @dishEffectiveColdLoss.
  ///
  /// In ru, this message translates to:
  /// **'Эффект. потери обработки: {value}%'**
  String dishEffectiveColdLoss(String value);

  /// No description provided for @dishTotalYieldSummary.
  ///
  /// In ru, this message translates to:
  /// **'Итого: {cost}  |  Выход: {yield}'**
  String dishTotalYieldSummary(String cost, String yield);

  /// No description provided for @dishGostNorms.
  ///
  /// In ru, this message translates to:
  /// **'ГОСТ нормы'**
  String get dishGostNorms;

  /// No description provided for @dishGostNormsTitle.
  ///
  /// In ru, this message translates to:
  /// **'ГОСТ нормы потерь'**
  String get dishGostNormsTitle;

  /// No description provided for @dishSearchProductHint.
  ///
  /// In ru, this message translates to:
  /// **'Поиск продукта...'**
  String get dishSearchProductHint;

  /// No description provided for @dishReferenceEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Справочник пуст'**
  String get dishReferenceEmpty;

  /// No description provided for @dishGostNotLoaded.
  ///
  /// In ru, this message translates to:
  /// **'Данные ГОСТ норм ещё не загружены'**
  String get dishGostNotLoaded;

  /// No description provided for @dishGostLossLine.
  ///
  /// In ru, this message translates to:
  /// **'Хол: {cold}%  Тепл: {hot}%'**
  String dishGostLossLine(String cold, String hot);

  /// No description provided for @dishPhotoSection.
  ///
  /// In ru, this message translates to:
  /// **'Фото блюда'**
  String get dishPhotoSection;

  /// No description provided for @dishMissingPricesWarning.
  ///
  /// In ru, this message translates to:
  /// **'Некоторые ингредиенты не имеют закупочной цены'**
  String get dishMissingPricesWarning;

  /// No description provided for @dishProfitPerServing.
  ///
  /// In ru, this message translates to:
  /// **'Прибыль с порции'**
  String get dishProfitPerServing;

  /// No description provided for @dishLossPerServing.
  ///
  /// In ru, this message translates to:
  /// **'Убыток с порции'**
  String get dishLossPerServing;

  /// No description provided for @dishCostOfDish.
  ///
  /// In ru, this message translates to:
  /// **'Себестоимость блюда'**
  String get dishCostOfDish;

  /// No description provided for @dishSellingPrice.
  ///
  /// In ru, this message translates to:
  /// **'Цена продажи'**
  String get dishSellingPrice;

  /// No description provided for @dishMargin.
  ///
  /// In ru, this message translates to:
  /// **'Маржа'**
  String get dishMargin;

  /// No description provided for @dishNoPhoto.
  ///
  /// In ru, this message translates to:
  /// **'Нет фото'**
  String get dishNoPhoto;

  /// No description provided for @dishPhotoLoaded.
  ///
  /// In ru, this message translates to:
  /// **'Фото загружено'**
  String get dishPhotoLoaded;

  /// No description provided for @dishPhotoAddHint.
  ///
  /// In ru, this message translates to:
  /// **'Добавьте фото готового блюда'**
  String get dishPhotoAddHint;

  /// No description provided for @dishCamera.
  ///
  /// In ru, this message translates to:
  /// **'Камера'**
  String get dishCamera;

  /// No description provided for @dishGallery.
  ///
  /// In ru, this message translates to:
  /// **'Галерея'**
  String get dishGallery;

  /// No description provided for @dishPhotoLoadError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить фото'**
  String get dishPhotoLoadError;

  /// No description provided for @dishFoodCost.
  ///
  /// In ru, this message translates to:
  /// **'Фудкост'**
  String get dishFoodCost;

  /// No description provided for @dishFoodCostExcellent.
  ///
  /// In ru, this message translates to:
  /// **'Отлично'**
  String get dishFoodCostExcellent;

  /// No description provided for @dishFoodCostNormal.
  ///
  /// In ru, this message translates to:
  /// **'Нормально'**
  String get dishFoodCostNormal;

  /// No description provided for @dishFoodCostHigh.
  ///
  /// In ru, this message translates to:
  /// **'Высокий'**
  String get dishFoodCostHigh;

  /// No description provided for @dishServingsCount.
  ///
  /// In ru, this message translates to:
  /// **'Кол-во порций:'**
  String get dishServingsCount;

  /// No description provided for @dishCostPerServing.
  ///
  /// In ru, this message translates to:
  /// **'Стоимость порции'**
  String get dishCostPerServing;

  /// No description provided for @dishPricePerServing.
  ///
  /// In ru, this message translates to:
  /// **'Цена порции'**
  String get dishPricePerServing;

  /// No description provided for @dishTotalYield.
  ///
  /// In ru, this message translates to:
  /// **'Общий выход'**
  String get dishTotalYield;

  /// No description provided for @dishIngredientsCount.
  ///
  /// In ru, this message translates to:
  /// **'Ингредиентов'**
  String get dishIngredientsCount;

  /// No description provided for @dishKbjuSection.
  ///
  /// In ru, this message translates to:
  /// **'Пищевая ценность (КБЖУ на 1 порцию)'**
  String get dishKbjuSection;

  /// No description provided for @dishKbjuEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Данные КБЖУ не заполнены'**
  String get dishKbjuEmpty;

  /// No description provided for @dishKbjuCalories.
  ///
  /// In ru, this message translates to:
  /// **'Калории'**
  String get dishKbjuCalories;

  /// No description provided for @dishKbjuProteins.
  ///
  /// In ru, this message translates to:
  /// **'Белки'**
  String get dishKbjuProteins;

  /// No description provided for @dishKbjuFats.
  ///
  /// In ru, this message translates to:
  /// **'Жиры'**
  String get dishKbjuFats;

  /// No description provided for @dishKbjuCarbs.
  ///
  /// In ru, this message translates to:
  /// **'Углеводы'**
  String get dishKbjuCarbs;

  /// No description provided for @dishKcalValue.
  ///
  /// In ru, this message translates to:
  /// **'{value} ккал'**
  String dishKcalValue(String value);

  /// No description provided for @dishGramValue.
  ///
  /// In ru, this message translates to:
  /// **'{value} г'**
  String dishGramValue(String value);

  /// No description provided for @dishVersionHistory.
  ///
  /// In ru, this message translates to:
  /// **'История изменений'**
  String get dishVersionHistory;

  /// No description provided for @dishNoVersions.
  ///
  /// In ru, this message translates to:
  /// **'Нет сохранённых версий'**
  String get dishNoVersions;

  /// No description provided for @dishVersionN.
  ///
  /// In ru, this message translates to:
  /// **'Версия {version}'**
  String dishVersionN(String version);

  /// No description provided for @dishViewComposition.
  ///
  /// In ru, this message translates to:
  /// **'Просмотреть состав'**
  String get dishViewComposition;

  /// No description provided for @dishRestoreThisVersion.
  ///
  /// In ru, this message translates to:
  /// **'Восстановить эту версию'**
  String get dishRestoreThisVersion;

  /// No description provided for @dishSaveVersion.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить версию'**
  String get dishSaveVersion;

  /// No description provided for @dishVersionComposition.
  ///
  /// In ru, this message translates to:
  /// **'Версия {version} — состав'**
  String dishVersionComposition(String version);

  /// No description provided for @dishSnapshotUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Снимок состава недоступен'**
  String get dishSnapshotUnavailable;

  /// No description provided for @dishSnapshotIngredientLine.
  ///
  /// In ru, this message translates to:
  /// **'Брутто: {gross}  |  Пот.обр.: {cold}%  |  Пот.т/о: {hot}%  |  Выход: {yield}'**
  String dishSnapshotIngredientLine(
    String gross,
    String cold,
    String hot,
    String yield,
  );

  /// No description provided for @dishVersionNotRestorable.
  ///
  /// In ru, this message translates to:
  /// **'Эту версию нельзя восстановить (нет данных об ингредиентах), доступен только просмотр'**
  String get dishVersionNotRestorable;

  /// No description provided for @dishRestoreVersionTitle.
  ///
  /// In ru, this message translates to:
  /// **'Восстановить версию?'**
  String get dishRestoreVersionTitle;

  /// No description provided for @dishRestoreVersionConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Текущая рецептура будет заменена составом версии {version}. Продолжить?'**
  String dishRestoreVersionConfirm(String version);

  /// No description provided for @dishRestore.
  ///
  /// In ru, this message translates to:
  /// **'Восстановить'**
  String get dishRestore;

  /// No description provided for @dishVersionRestored.
  ///
  /// In ru, this message translates to:
  /// **'Восстановлена версия {version}'**
  String dishVersionRestored(String version);

  /// No description provided for @dishRestoreError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось восстановить версию'**
  String get dishRestoreError;

  /// No description provided for @dishVersionSummary.
  ///
  /// In ru, this message translates to:
  /// **'Ингредиентов: {count}, себестоимость: {cost}'**
  String dishVersionSummary(int count, String cost);

  /// No description provided for @dishSaveVersionError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось сохранить версию рецепта'**
  String get dishSaveVersionError;

  /// No description provided for @prodBarcodeAutoHint.
  ///
  /// In ru, this message translates to:
  /// **'Авто'**
  String get prodBarcodeAutoHint;

  /// No description provided for @prodCatalogAttributes.
  ///
  /// In ru, this message translates to:
  /// **'Каталожные атрибуты'**
  String get prodCatalogAttributes;

  /// No description provided for @prodBrand.
  ///
  /// In ru, this message translates to:
  /// **'Бренд'**
  String get prodBrand;

  /// No description provided for @prodManufacturer.
  ///
  /// In ru, this message translates to:
  /// **'Производитель'**
  String get prodManufacturer;

  /// No description provided for @prodCountryOfOrigin.
  ///
  /// In ru, this message translates to:
  /// **'Страна происхождения'**
  String get prodCountryOfOrigin;

  /// No description provided for @prodFiscalAttributes.
  ///
  /// In ru, this message translates to:
  /// **'Фискальные атрибуты'**
  String get prodFiscalAttributes;

  /// No description provided for @prodVatRate.
  ///
  /// In ru, this message translates to:
  /// **'Ставка НДС'**
  String get prodVatRate;

  /// No description provided for @prodVatNone.
  ///
  /// In ru, this message translates to:
  /// **'Без НДС'**
  String get prodVatNone;

  /// No description provided for @prodNtin.
  ///
  /// In ru, this message translates to:
  /// **'НКТ (НТИН)'**
  String get prodNtin;

  /// No description provided for @prodMarkable.
  ///
  /// In ru, this message translates to:
  /// **'Подлежит маркировке'**
  String get prodMarkable;

  /// No description provided for @promoTitle.
  ///
  /// In ru, this message translates to:
  /// **'Акции'**
  String get promoTitle;

  /// No description provided for @promoSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Акции 1+1 и подарки за покупку'**
  String get promoSubtitle;

  /// No description provided for @promoNew.
  ///
  /// In ru, this message translates to:
  /// **'Новая акция'**
  String get promoNew;

  /// No description provided for @promoError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка: {error}'**
  String promoError(String error);

  /// No description provided for @promoEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Нет акций'**
  String get promoEmpty;

  /// No description provided for @promoEmptyHint.
  ///
  /// In ru, this message translates to:
  /// **'Создайте акцию 1+1 или Подарок'**
  String get promoEmptyHint;

  /// No description provided for @promoTypeGift.
  ///
  /// In ru, this message translates to:
  /// **'Подарок'**
  String get promoTypeGift;

  /// No description provided for @promoBuyGetFree.
  ///
  /// In ru, this message translates to:
  /// **'купи {trigger} → {reward} бесплатно'**
  String promoBuyGetFree(int trigger, int reward);

  /// No description provided for @promoDefaultName11.
  ///
  /// In ru, this message translates to:
  /// **'Акция 1+1'**
  String get promoDefaultName11;

  /// No description provided for @promoNameLabel.
  ///
  /// In ru, this message translates to:
  /// **'Название'**
  String get promoNameLabel;

  /// No description provided for @promoTriggerLabel.
  ///
  /// In ru, this message translates to:
  /// **'Товар-триггер (что купить)'**
  String get promoTriggerLabel;

  /// No description provided for @promoRewardLabel.
  ///
  /// In ru, this message translates to:
  /// **'Подарок (что бесплатно)'**
  String get promoRewardLabel;

  /// No description provided for @promoSaveButton.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить акцию'**
  String get promoSaveButton;

  /// No description provided for @saleWeighingPlaceItem.
  ///
  /// In ru, this message translates to:
  /// **'Взвешивание... поместите товар на весы'**
  String get saleWeighingPlaceItem;

  /// No description provided for @saleWeightReadFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось считать вес — введите вручную'**
  String get saleWeightReadFailed;

  /// No description provided for @salePriceLabelSent.
  ///
  /// In ru, this message translates to:
  /// **'Ценник отправлен на печать'**
  String get salePriceLabelSent;

  /// No description provided for @transPrimary.
  ///
  /// In ru, this message translates to:
  /// **'Основной'**
  String get transPrimary;

  /// No description provided for @transSecondary.
  ///
  /// In ru, this message translates to:
  /// **'Резервный'**
  String get transSecondary;

  /// No description provided for @transStatusOnline.
  ///
  /// In ru, this message translates to:
  /// **'В сети'**
  String get transStatusOnline;

  /// No description provided for @transStatusOffline.
  ///
  /// In ru, this message translates to:
  /// **'Не в сети'**
  String get transStatusOffline;

  /// No description provided for @transStatusSyncing.
  ///
  /// In ru, this message translates to:
  /// **'Синхронизация'**
  String get transStatusSyncing;

  /// No description provided for @transStatusQueued.
  ///
  /// In ru, this message translates to:
  /// **'В очереди'**
  String get transStatusQueued;

  /// No description provided for @transStatusWarning.
  ///
  /// In ru, this message translates to:
  /// **'Предупреждение'**
  String get transStatusWarning;

  /// No description provided for @transStatusError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка'**
  String get transStatusError;

  /// No description provided for @transQueuedCount.
  ///
  /// In ru, this message translates to:
  /// **'{count} в очереди'**
  String transQueuedCount(int count);

  /// No description provided for @transFailedCount.
  ///
  /// In ru, this message translates to:
  /// **'{count} с ошибкой'**
  String transFailedCount(int count);

  /// No description provided for @transLastSyncAgo.
  ///
  /// In ru, this message translates to:
  /// **'Последняя синхронизация: {ago} назад'**
  String transLastSyncAgo(String ago);

  /// No description provided for @transSyncing.
  ///
  /// In ru, this message translates to:
  /// **'Синхронизация...'**
  String get transSyncing;

  /// No description provided for @transSyncNow.
  ///
  /// In ru, this message translates to:
  /// **'Синхронизировать'**
  String get transSyncNow;

  /// No description provided for @transRetryFailed.
  ///
  /// In ru, this message translates to:
  /// **'Повторить неудавшиеся'**
  String get transRetryFailed;

  /// No description provided for @restTips.
  ///
  /// In ru, this message translates to:
  /// **'Чаевые'**
  String get restTips;

  /// No description provided for @restNoTips.
  ///
  /// In ru, this message translates to:
  /// **'Без чаевых'**
  String get restNoTips;

  /// No description provided for @svcPendingApproval.
  ///
  /// In ru, this message translates to:
  /// **'Ожидает согласования'**
  String get svcPendingApproval;

  /// No description provided for @svcApprove.
  ///
  /// In ru, this message translates to:
  /// **'Согласовать'**
  String get svcApprove;

  /// No description provided for @svcReject.
  ///
  /// In ru, this message translates to:
  /// **'Отклонить'**
  String get svcReject;

  /// No description provided for @svcRejected.
  ///
  /// In ru, this message translates to:
  /// **'Отклонено'**
  String get svcRejected;

  /// No description provided for @svcQr.
  ///
  /// In ru, this message translates to:
  /// **'QR'**
  String get svcQr;

  /// No description provided for @catCollapse.
  ///
  /// In ru, this message translates to:
  /// **'Свернуть'**
  String get catCollapse;

  /// No description provided for @repError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка'**
  String get repError;

  /// No description provided for @repNoData.
  ///
  /// In ru, this message translates to:
  /// **'Нет данных'**
  String get repNoData;

  /// No description provided for @repNoDataForPeriod.
  ///
  /// In ru, this message translates to:
  /// **'Нет данных за выбранный период'**
  String get repNoDataForPeriod;

  /// No description provided for @repKpiLoadError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка загрузки KPI'**
  String get repKpiLoadError;

  /// No description provided for @repColIndicator.
  ///
  /// In ru, this message translates to:
  /// **'Показатель'**
  String get repColIndicator;

  /// No description provided for @repColCount.
  ///
  /// In ru, this message translates to:
  /// **'Кол-во'**
  String get repColCount;

  /// No description provided for @repColSumTenge.
  ///
  /// In ru, this message translates to:
  /// **'Сумма, {currency}'**
  String repColSumTenge(String currency);

  /// No description provided for @repColRow.
  ///
  /// In ru, this message translates to:
  /// **'Строка'**
  String get repColRow;

  /// No description provided for @repColTurnoverExclVat.
  ///
  /// In ru, this message translates to:
  /// **'Оборот (без НДС)'**
  String get repColTurnoverExclVat;

  /// No description provided for @repColVat.
  ///
  /// In ru, this message translates to:
  /// **'НДС'**
  String get repColVat;

  /// No description provided for @repColDate.
  ///
  /// In ru, this message translates to:
  /// **'Дата'**
  String get repColDate;

  /// No description provided for @repColOperation.
  ///
  /// In ru, this message translates to:
  /// **'Операция'**
  String get repColOperation;

  /// No description provided for @repColIncome.
  ///
  /// In ru, this message translates to:
  /// **'Приход'**
  String get repColIncome;

  /// No description provided for @repColExpense.
  ///
  /// In ru, this message translates to:
  /// **'Расход'**
  String get repColExpense;

  /// No description provided for @repColBalance.
  ///
  /// In ru, this message translates to:
  /// **'Остаток'**
  String get repColBalance;

  /// No description provided for @repColRate.
  ///
  /// In ru, this message translates to:
  /// **'Ставка'**
  String get repColRate;

  /// No description provided for @repColGross.
  ///
  /// In ru, this message translates to:
  /// **'Брутто'**
  String get repColGross;

  /// No description provided for @repColNet.
  ///
  /// In ru, this message translates to:
  /// **'Нетто'**
  String get repColNet;

  /// No description provided for @repNoVat.
  ///
  /// In ru, this message translates to:
  /// **'Без НДС'**
  String get repNoVat;

  /// No description provided for @repColCounterparty.
  ///
  /// In ru, this message translates to:
  /// **'Контрагент'**
  String get repColCounterparty;

  /// No description provided for @repColType.
  ///
  /// In ru, this message translates to:
  /// **'Тип'**
  String get repColType;

  /// No description provided for @repColSaldo.
  ///
  /// In ru, this message translates to:
  /// **'Сальдо'**
  String get repColSaldo;

  /// No description provided for @repDebtor.
  ///
  /// In ru, this message translates to:
  /// **'Дебитор'**
  String get repDebtor;

  /// No description provided for @repCreditor.
  ///
  /// In ru, this message translates to:
  /// **'Кредитор'**
  String get repCreditor;

  /// No description provided for @repColAccount.
  ///
  /// In ru, this message translates to:
  /// **'Счёт'**
  String get repColAccount;

  /// No description provided for @repColCashier.
  ///
  /// In ru, this message translates to:
  /// **'Кассир'**
  String get repColCashier;

  /// No description provided for @repColAmount.
  ///
  /// In ru, this message translates to:
  /// **'Сумма'**
  String get repColAmount;

  /// No description provided for @repColProduct.
  ///
  /// In ru, this message translates to:
  /// **'Товар'**
  String get repColProduct;

  /// No description provided for @repColRevenue.
  ///
  /// In ru, this message translates to:
  /// **'Выручка'**
  String get repColRevenue;

  /// No description provided for @repColCogs.
  ///
  /// In ru, this message translates to:
  /// **'Себест.'**
  String get repColCogs;

  /// No description provided for @repColProfit.
  ///
  /// In ru, this message translates to:
  /// **'Прибыль'**
  String get repColProfit;

  /// No description provided for @repColMarginPct.
  ///
  /// In ru, this message translates to:
  /// **'Маржа %'**
  String get repColMarginPct;

  /// No description provided for @repColReason.
  ///
  /// In ru, this message translates to:
  /// **'Причина'**
  String get repColReason;

  /// No description provided for @repColDocuments.
  ///
  /// In ru, this message translates to:
  /// **'Документов'**
  String get repColDocuments;

  /// No description provided for @repColCostShort.
  ///
  /// In ru, this message translates to:
  /// **'Себест.'**
  String get repColCostShort;

  /// No description provided for @repF910Title.
  ///
  /// In ru, this message translates to:
  /// **'ф.910 — Доход (упрощёнка)'**
  String get repF910Title;

  /// No description provided for @repF910Subtitle.
  ///
  /// In ru, this message translates to:
  /// **'Облагаемый доход: {income} • налог {rate}%: {tax}'**
  String repF910Subtitle(String income, String rate, String tax);

  /// No description provided for @repF910RowSalesIncome.
  ///
  /// In ru, this message translates to:
  /// **'Доход с продаж'**
  String get repF910RowSalesIncome;

  /// No description provided for @repF910RowRefunds.
  ///
  /// In ru, this message translates to:
  /// **'Возвраты (минус)'**
  String get repF910RowRefunds;

  /// No description provided for @repF910RowTaxableIncome.
  ///
  /// In ru, this message translates to:
  /// **'Облагаемый доход'**
  String get repF910RowTaxableIncome;

  /// No description provided for @repF300Title.
  ///
  /// In ru, this message translates to:
  /// **'ф.300 — НДС (декларация)'**
  String get repF300Title;

  /// No description provided for @repF300Subtitle.
  ///
  /// In ru, this message translates to:
  /// **'Облагаемый оборот: {turnover} • начисленный НДС: {vat}'**
  String repF300Subtitle(String turnover, String vat);

  /// No description provided for @repF300TaxableTurnoverRate.
  ///
  /// In ru, this message translates to:
  /// **'Облагаемый оборот {rate}%'**
  String repF300TaxableTurnoverRate(String rate);

  /// No description provided for @repF300ZeroRatedTurnover.
  ///
  /// In ru, this message translates to:
  /// **'Необлагаемый / 0% оборот'**
  String get repF300ZeroRatedTurnover;

  /// No description provided for @repCashBookTitle.
  ///
  /// In ru, this message translates to:
  /// **'Кассовая книга (КО-4)'**
  String get repCashBookTitle;

  /// No description provided for @repCashBookSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Приход: {income} • Расход: {expense} • Остаток: {balance}'**
  String repCashBookSubtitle(String income, String expense, String balance);

  /// No description provided for @repVatPeriodTitle.
  ///
  /// In ru, this message translates to:
  /// **'НДС за период'**
  String get repVatPeriodTitle;

  /// No description provided for @repVatPeriodSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'НДС: {vat} • база: {base}'**
  String repVatPeriodSubtitle(String vat, String base);

  /// No description provided for @repArApTitle.
  ///
  /// In ru, this message translates to:
  /// **'Дебиторка / Кредиторка'**
  String get repArApTitle;

  /// No description provided for @repArApSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Дебиторка: {receivable} • Кредиторка: {payable} • Сальдо: {saldo}'**
  String repArApSubtitle(String receivable, String payable, String saldo);

  /// No description provided for @repCashCollectionTitle.
  ///
  /// In ru, this message translates to:
  /// **'Инкассация'**
  String get repCashCollectionTitle;

  /// No description provided for @repCashCollectionSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'{count} операций • всего: {total}'**
  String repCashCollectionSubtitle(int count, String total);

  /// No description provided for @repProfitCogsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Прибыль / Маржа (COGS)'**
  String get repProfitCogsTitle;

  /// No description provided for @repProfitMarginTitle.
  ///
  /// In ru, this message translates to:
  /// **'Прибыль / Маржа'**
  String get repProfitMarginTitle;

  /// No description provided for @repProfitMarginSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Прибыль: {profit} • маржа {margin}% • {note}'**
  String repProfitMarginSubtitle(String profit, String margin, String note);

  /// No description provided for @repProfitCostRealCogs.
  ///
  /// In ru, this message translates to:
  /// **'себестоимость: реальный COGS'**
  String get repProfitCostRealCogs;

  /// No description provided for @repProfitCostWholesale.
  ///
  /// In ru, this message translates to:
  /// **'себестоимость: оптовая цена (нет CalculateCogsUseCase)'**
  String get repProfitCostWholesale;

  /// No description provided for @repWriteoffTitle.
  ///
  /// In ru, this message translates to:
  /// **'Списания'**
  String get repWriteoffTitle;

  /// No description provided for @repWriteoffSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'{count} документов • всего: {total}'**
  String repWriteoffSubtitle(int count, String total);

  /// No description provided for @repOrderTypesTitle.
  ///
  /// In ru, this message translates to:
  /// **'Типы заказов'**
  String get repOrderTypesTitle;

  /// No description provided for @repOrderTypesSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'распределение по типу обслуживания'**
  String get repOrderTypesSubtitle;

  /// No description provided for @repTableTurnoverTitle.
  ///
  /// In ru, this message translates to:
  /// **'Оборот столов'**
  String get repTableTurnoverTitle;

  /// No description provided for @repTableTurnoverSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'посадок за период (топ-10)'**
  String get repTableTurnoverSubtitle;

  /// No description provided for @repDishPopularityTitle.
  ///
  /// In ru, this message translates to:
  /// **'Популярность блюд'**
  String get repDishPopularityTitle;

  /// No description provided for @repDishPopularitySubtitle.
  ///
  /// In ru, this message translates to:
  /// **'топ-10 по количеству продаж'**
  String get repDishPopularitySubtitle;

  /// No description provided for @repFoodCostAnalysisShort.
  ///
  /// In ru, this message translates to:
  /// **'Анализ себестоимости'**
  String get repFoodCostAnalysisShort;

  /// No description provided for @repFoodCostAnalysisTitle.
  ///
  /// In ru, this message translates to:
  /// **'Анализ себестоимости (Food Cost)'**
  String get repFoodCostAnalysisTitle;

  /// No description provided for @repFoodCostAnalysisSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'зеленый <30%, желтый 30-40%, красный >40%'**
  String get repFoodCostAnalysisSubtitle;

  /// No description provided for @repColDish.
  ///
  /// In ru, this message translates to:
  /// **'Блюдо'**
  String get repColDish;

  /// No description provided for @repColFoodCostPct.
  ///
  /// In ru, this message translates to:
  /// **'Food Cost %'**
  String get repColFoodCostPct;

  /// No description provided for @repTipsByWaiterTitle.
  ///
  /// In ru, this message translates to:
  /// **'Чаевые по официантам'**
  String get repTipsByWaiterTitle;

  /// No description provided for @repTipsByWaiterSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'сортировка по сумме чаевых'**
  String get repTipsByWaiterSubtitle;

  /// No description provided for @repColWaiter.
  ///
  /// In ru, this message translates to:
  /// **'Официант'**
  String get repColWaiter;

  /// No description provided for @repColOrders.
  ///
  /// In ru, this message translates to:
  /// **'Заказы'**
  String get repColOrders;

  /// No description provided for @repColTips.
  ///
  /// In ru, this message translates to:
  /// **'Чаевые'**
  String get repColTips;

  /// No description provided for @repColTipsPct.
  ///
  /// In ru, this message translates to:
  /// **'Чаевые %'**
  String get repColTipsPct;

  /// No description provided for @repKpiRestaurantRevenue.
  ///
  /// In ru, this message translates to:
  /// **'Выручка ресторана'**
  String get repKpiRestaurantRevenue;

  /// No description provided for @repKpiOrders.
  ///
  /// In ru, this message translates to:
  /// **'Заказы'**
  String get repKpiOrders;

  /// No description provided for @repKpiAvgCheck.
  ///
  /// In ru, this message translates to:
  /// **'Средний чек'**
  String get repKpiAvgCheck;

  /// No description provided for @repKpiTips.
  ///
  /// In ru, this message translates to:
  /// **'Чаевые'**
  String get repKpiTips;

  /// No description provided for @repKpiRevenue.
  ///
  /// In ru, this message translates to:
  /// **'Выручка'**
  String get repKpiRevenue;

  /// No description provided for @repKpiExpenses.
  ///
  /// In ru, this message translates to:
  /// **'Расходы'**
  String get repKpiExpenses;

  /// No description provided for @repKpiRefunds.
  ///
  /// In ru, this message translates to:
  /// **'Возвраты'**
  String get repKpiRefunds;

  /// No description provided for @repKpiSales.
  ///
  /// In ru, this message translates to:
  /// **'Продажи'**
  String get repKpiSales;

  /// No description provided for @repSubtitleForPeriod.
  ///
  /// In ru, this message translates to:
  /// **'за период'**
  String get repSubtitleForPeriod;

  /// No description provided for @repSubtitleTotal.
  ///
  /// In ru, this message translates to:
  /// **'всего'**
  String get repSubtitleTotal;

  /// No description provided for @repSubtitleCashExpenses.
  ///
  /// In ru, this message translates to:
  /// **'кассовые расходы'**
  String get repSubtitleCashExpenses;

  /// No description provided for @repSubtitleRefundTotal.
  ///
  /// In ru, this message translates to:
  /// **'сумма возвратов'**
  String get repSubtitleRefundTotal;

  /// No description provided for @repSubtitleReceipts.
  ///
  /// In ru, this message translates to:
  /// **'чеков'**
  String get repSubtitleReceipts;

  /// No description provided for @repCashFlowTitle.
  ///
  /// In ru, this message translates to:
  /// **'Денежный поток по дням'**
  String get repCashFlowTitle;

  /// No description provided for @repCashFlowInvestments.
  ///
  /// In ru, this message translates to:
  /// **'Вложения'**
  String get repCashFlowInvestments;

  /// No description provided for @repCashFlowExpenses.
  ///
  /// In ru, this message translates to:
  /// **'Расходы'**
  String get repCashFlowExpenses;

  /// No description provided for @repCashFlowDividends.
  ///
  /// In ru, this message translates to:
  /// **'Дивиденды'**
  String get repCashFlowDividends;

  /// No description provided for @repDaysCount.
  ///
  /// In ru, this message translates to:
  /// **'{count} дней'**
  String repDaysCount(int count);

  /// No description provided for @repTopProfitableTitle.
  ///
  /// In ru, this message translates to:
  /// **'Топ-10 прибыльных товаров'**
  String get repTopProfitableTitle;

  /// No description provided for @repTopProfitableSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'по абсолютной прибыли'**
  String get repTopProfitableSubtitle;

  /// No description provided for @repProductProfitTitle.
  ///
  /// In ru, this message translates to:
  /// **'Рентабельность товаров'**
  String get repProductProfitTitle;

  /// No description provided for @repProductProfitSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'топ-20 по прибыли'**
  String get repProductProfitSubtitle;

  /// No description provided for @repRefundTrendTitle.
  ///
  /// In ru, this message translates to:
  /// **'Тренд возвратов'**
  String get repRefundTrendTitle;

  /// No description provided for @repSupplierVolumeTitle.
  ///
  /// In ru, this message translates to:
  /// **'Поставки по поставщикам'**
  String get repSupplierVolumeTitle;

  /// No description provided for @repSuppliersCount.
  ///
  /// In ru, this message translates to:
  /// **'{count} поставщиков'**
  String repSuppliersCount(int count);

  /// No description provided for @repSupplierTableTitle.
  ///
  /// In ru, this message translates to:
  /// **'Таблица поставщиков'**
  String get repSupplierTableTitle;

  /// No description provided for @repSupplierTableSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'сортировка по количеству поставок'**
  String get repSupplierTableSubtitle;

  /// No description provided for @repColSupplier.
  ///
  /// In ru, this message translates to:
  /// **'Поставщик'**
  String get repColSupplier;

  /// No description provided for @repColSupplyCount.
  ///
  /// In ru, this message translates to:
  /// **'Кол-во поставок'**
  String get repColSupplyCount;

  /// No description provided for @repPriceTrendTitle.
  ///
  /// In ru, this message translates to:
  /// **'Динамика закупочных цен'**
  String get repPriceTrendTitle;

  /// No description provided for @repPriceTrendSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'топ-5 товаров по количеству поставок'**
  String get repPriceTrendSubtitle;

  /// No description provided for @repNotEnoughDataForChart.
  ///
  /// In ru, this message translates to:
  /// **'Недостаточно данных для графика'**
  String get repNotEnoughDataForChart;

  /// No description provided for @repPriceChangesShort.
  ///
  /// In ru, this message translates to:
  /// **'Изменения цен'**
  String get repPriceChangesShort;

  /// No description provided for @repPriceChangesTitle.
  ///
  /// In ru, this message translates to:
  /// **'Изменения цен поставщиков'**
  String get repPriceChangesTitle;

  /// No description provided for @repPriceChangesSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'последние изменения закупочных цен'**
  String get repPriceChangesSubtitle;

  /// No description provided for @repColWas.
  ///
  /// In ru, this message translates to:
  /// **'Было'**
  String get repColWas;

  /// No description provided for @repColBecame.
  ///
  /// In ru, this message translates to:
  /// **'Стало'**
  String get repColBecame;

  /// No description provided for @repColChangePctShort.
  ///
  /// In ru, this message translates to:
  /// **'Изм. %'**
  String get repColChangePctShort;

  /// No description provided for @repNoSupplierData.
  ///
  /// In ru, this message translates to:
  /// **'Нет данных о поставщиках'**
  String get repNoSupplierData;

  /// No description provided for @repNoSuppliesForPeriod.
  ///
  /// In ru, this message translates to:
  /// **'За выбранный период поставки не найдены'**
  String get repNoSuppliesForPeriod;

  /// No description provided for @navWmsDashboard.
  ///
  /// In ru, this message translates to:
  /// **'Склад WMS'**
  String get navWmsDashboard;

  /// No description provided for @navWmsWarehouses.
  ///
  /// In ru, this message translates to:
  /// **'Склады'**
  String get navWmsWarehouses;

  /// No description provided for @navWmsBatches.
  ///
  /// In ru, this message translates to:
  /// **'Партии'**
  String get navWmsBatches;

  /// No description provided for @navWmsSerials.
  ///
  /// In ru, this message translates to:
  /// **'Серии'**
  String get navWmsSerials;

  /// No description provided for @navWmsCellStock.
  ///
  /// In ru, this message translates to:
  /// **'Ячейки'**
  String get navWmsCellStock;

  /// No description provided for @navWmsClaims.
  ///
  /// In ru, this message translates to:
  /// **'Рекламации'**
  String get navWmsClaims;

  /// No description provided for @navWmsMarking.
  ///
  /// In ru, this message translates to:
  /// **'Маркировка'**
  String get navWmsMarking;

  /// No description provided for @navWmsSettings.
  ///
  /// In ru, this message translates to:
  /// **'Настройки WMS'**
  String get navWmsSettings;

  /// No description provided for @errorInsufficientStock.
  ///
  /// In ru, this message translates to:
  /// **'Недостаточно остатка: {name}'**
  String errorInsufficientStock(String name);

  /// No description provided for @discountLimitsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Пределы скидки'**
  String get discountLimitsTitle;

  /// No description provided for @discountLimitsSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Сколько кассир может уступить вручную'**
  String get discountLimitsSubtitle;

  /// No description provided for @discountLimitsIntro.
  ///
  /// In ru, this message translates to:
  /// **'Предел роли перекрывает умолчание. У роли без своей строки действует «По умолчанию». Сто процентов означает «без предела» — это объявленное значение, а не пустота.'**
  String get discountLimitsIntro;

  /// No description provided for @discountLimitsDefaultRow.
  ///
  /// In ru, this message translates to:
  /// **'По умолчанию (все роли)'**
  String get discountLimitsDefaultRow;

  /// No description provided for @discountLimitsMaxPercent.
  ///
  /// In ru, this message translates to:
  /// **'Предел, %'**
  String get discountLimitsMaxPercent;

  /// No description provided for @discountLimitsApprovalAbove.
  ///
  /// In ru, this message translates to:
  /// **'Подтверждение выше, %'**
  String get discountLimitsApprovalAbove;

  /// No description provided for @discountLimitsApprovalHint.
  ///
  /// In ru, this message translates to:
  /// **'пусто — не требуется'**
  String get discountLimitsApprovalHint;

  /// No description provided for @discountLimitsInheritHint.
  ///
  /// In ru, this message translates to:
  /// **'пусто — как по умолчанию'**
  String get discountLimitsInheritHint;

  /// No description provided for @discountLimitsTwoDoors.
  ///
  /// In ru, this message translates to:
  /// **'Внимание: «запретить снижение цены» в политике продаж закрывает только правку цены строки. Скидка при пределе 100 % по-прежнему разрешена — вплоть до строки бесплатно. Это две разные двери; чтобы закрыть вторую, поставьте предел ниже ста.'**
  String get discountLimitsTwoDoors;

  /// No description provided for @discountLimitsSaved.
  ///
  /// In ru, this message translates to:
  /// **'Предел сохранён'**
  String get discountLimitsSaved;

  /// No description provided for @discountLimitsInherited.
  ///
  /// In ru, this message translates to:
  /// **'Строка снята: роль наследует умолчание'**
  String get discountLimitsInherited;

  /// No description provided for @discountLimitsInvalid.
  ///
  /// In ru, this message translates to:
  /// **'Предел — число от 0 до 100'**
  String get discountLimitsInvalid;

  /// No description provided for @discountLimitsApprovalNotYet.
  ///
  /// In ru, this message translates to:
  /// **'Подтверждение старшего пока не реализовано: скидка выше порога отклоняется с названной причиной, а не открывает ввод кода.'**
  String get discountLimitsApprovalNotYet;

  /// No description provided for @errorDeniedPolicy.
  ///
  /// In ru, this message translates to:
  /// **'Запрещено настройками кассы: {detail}'**
  String errorDeniedPolicy(String detail);

  /// No description provided for @errorDeniedLimit.
  ///
  /// In ru, this message translates to:
  /// **'Скидка больше разрешённой: {detail}'**
  String errorDeniedLimit(String detail);

  /// No description provided for @errorApprovalRequired.
  ///
  /// In ru, this message translates to:
  /// **'Нужно подтверждение старшего: {detail}'**
  String errorApprovalRequired(String detail);

  /// No description provided for @errorBigAmountBlocked.
  ///
  /// In ru, this message translates to:
  /// **'Сумма продажи выше потолка кассы ({limit}). Поднимите потолок или включите разрешение на крупные суммы в настройках кассы.'**
  String errorBigAmountBlocked(String limit);

  /// No description provided for @errorMarkRequired.
  ///
  /// In ru, this message translates to:
  /// **'Требуется код маркировки: {name}'**
  String errorMarkRequired(String name);

  /// No description provided for @errorOrderNotFound.
  ///
  /// In ru, this message translates to:
  /// **'Заказ не найден'**
  String get errorOrderNotFound;

  /// No description provided for @errorSerialNotFound.
  ///
  /// In ru, this message translates to:
  /// **'Серийный номер не найден'**
  String get errorSerialNotFound;

  /// No description provided for @errorReceiptFailedPrint.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось напечатать чек'**
  String get errorReceiptFailedPrint;

  /// No description provided for @errorDeleteFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось удалить'**
  String get errorDeleteFailed;

  /// No description provided for @errorCancelFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось отменить'**
  String get errorCancelFailed;

  /// No description provided for @errorShiftZreportFailed.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка Z-отчёта'**
  String get errorShiftZreportFailed;

  /// No description provided for @errorTransitionFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось изменить статус'**
  String get errorTransitionFailed;

  /// No description provided for @logJournalTitle.
  ///
  /// In ru, this message translates to:
  /// **'Журнал работы'**
  String get logJournalTitle;

  /// No description provided for @logJournalOpen.
  ///
  /// In ru, this message translates to:
  /// **'Открыть журнал'**
  String get logJournalOpen;

  /// No description provided for @logJournalCardDesc.
  ///
  /// In ru, this message translates to:
  /// **'Файловый журнал работы по датам: выгрузка на флешку, очистка'**
  String get logJournalCardDesc;

  /// No description provided for @logJournalEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Журнал пуст'**
  String get logJournalEmpty;

  /// No description provided for @logJournalPickFolder.
  ///
  /// In ru, this message translates to:
  /// **'Выберите папку (флешку) для выгрузки'**
  String get logJournalPickFolder;

  /// No description provided for @logJournalExport.
  ///
  /// In ru, this message translates to:
  /// **'Скачать на флешку'**
  String get logJournalExport;

  /// No description provided for @logJournalExported.
  ///
  /// In ru, this message translates to:
  /// **'Выгружено {count} файлов в {dir}'**
  String logJournalExported(int count, String dir);

  /// No description provided for @logJournalSummary.
  ///
  /// In ru, this message translates to:
  /// **'Файлов: {count}, всего {size}'**
  String logJournalSummary(int count, String size);

  /// No description provided for @logJournalDeleteOld.
  ///
  /// In ru, this message translates to:
  /// **'Старше 7 дней'**
  String get logJournalDeleteOld;

  /// No description provided for @logJournalDeletedOld.
  ///
  /// In ru, this message translates to:
  /// **'Удалено файлов: {count}'**
  String logJournalDeletedOld(int count);

  /// No description provided for @logJournalDeleteAllTitle.
  ///
  /// In ru, this message translates to:
  /// **'Удалить все журналы?'**
  String get logJournalDeleteAllTitle;

  /// No description provided for @logJournalDeleteAllConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Будут удалены все файлы журнала, кроме сегодняшнего. Действие необратимо.'**
  String get logJournalDeleteAllConfirm;

  /// No description provided for @setUserTabPin.
  ///
  /// In ru, this message translates to:
  /// **'PIN'**
  String get setUserTabPin;

  /// No description provided for @setUserPinChange.
  ///
  /// In ru, this message translates to:
  /// **'Сменить PIN'**
  String get setUserPinChange;

  /// No description provided for @setUserPinSetHint.
  ///
  /// In ru, this message translates to:
  /// **'Задайте PIN-код (4–6 цифр) для входа пользователя'**
  String get setUserPinSetHint;

  /// No description provided for @setUserPinKeepHint.
  ///
  /// In ru, this message translates to:
  /// **'Оставьте пустым, чтобы не менять текущий PIN'**
  String get setUserPinKeepHint;

  /// No description provided for @setUserPinNew.
  ///
  /// In ru, this message translates to:
  /// **'Новый PIN'**
  String get setUserPinNew;

  /// No description provided for @receiptInputRecent.
  ///
  /// In ru, this message translates to:
  /// **'Последние чеки'**
  String get receiptInputRecent;

  /// No description provided for @receiptInputNoRecent.
  ///
  /// In ru, this message translates to:
  /// **'Чеков пока нет'**
  String get receiptInputNoRecent;

  /// No description provided for @receiptInputRecentUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Список последних чеков на этом терминале недоступен — введите номер чека вручную'**
  String get receiptInputRecentUnavailable;

  /// No description provided for @shiftHistoryTitle.
  ///
  /// In ru, this message translates to:
  /// **'История смен'**
  String get shiftHistoryTitle;

  /// No description provided for @shiftHistoryEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Закрытых смен пока нет'**
  String get shiftHistoryEmpty;

  /// No description provided for @shiftHistoryShiftNo.
  ///
  /// In ru, this message translates to:
  /// **'Смена №{id}'**
  String shiftHistoryShiftNo(int id);

  /// No description provided for @shiftHistorySales.
  ///
  /// In ru, this message translates to:
  /// **'Продажи'**
  String get shiftHistorySales;

  /// No description provided for @shiftHistoryRefunds.
  ///
  /// In ru, this message translates to:
  /// **'Возвраты'**
  String get shiftHistoryRefunds;

  /// No description provided for @shiftHistoryOpeningCash.
  ///
  /// In ru, this message translates to:
  /// **'Разменный'**
  String get shiftHistoryOpeningCash;

  /// No description provided for @saleExpiredBatchWarning.
  ///
  /// In ru, this message translates to:
  /// **'Внимание: у товара «{name}» истёк срок годности партии'**
  String saleExpiredBatchWarning(String name);

  /// No description provided for @setPolicyEditProduct.
  ///
  /// In ru, this message translates to:
  /// **'Разрешить редактирование товаров'**
  String get setPolicyEditProduct;

  /// No description provided for @setPolicyEditProductDesc.
  ///
  /// In ru, this message translates to:
  /// **'Кассир может изменять карточки товаров в каталоге'**
  String get setPolicyEditProductDesc;

  /// No description provided for @setPolicyEditPrice.
  ///
  /// In ru, this message translates to:
  /// **'Разрешить изменение цены в продаже'**
  String get setPolicyEditPrice;

  /// No description provided for @setPolicyEditPriceDesc.
  ///
  /// In ru, this message translates to:
  /// **'Кассир может вручную менять цену позиции в чеке'**
  String get setPolicyEditPriceDesc;

  /// No description provided for @setPolicyDiscounts.
  ///
  /// In ru, this message translates to:
  /// **'Разрешить скидки'**
  String get setPolicyDiscounts;

  /// No description provided for @setPolicyDiscountsDesc.
  ///
  /// In ru, this message translates to:
  /// **'Кассир может применять скидки к позициям чека'**
  String get setPolicyDiscountsDesc;

  /// No description provided for @setPolicyCashInOut.
  ///
  /// In ru, this message translates to:
  /// **'Разрешить внесение/изъятие наличных'**
  String get setPolicyCashInOut;

  /// No description provided for @setPolicyCashInOutDesc.
  ///
  /// In ru, this message translates to:
  /// **'Кассир может вносить и изымать наличные из кассы'**
  String get setPolicyCashInOutDesc;

  /// No description provided for @setPolicyBigAmount.
  ///
  /// In ru, this message translates to:
  /// **'Разрешить крупные суммы (>1 млн)'**
  String get setPolicyBigAmount;

  /// No description provided for @setPolicyBigAmountDesc.
  ///
  /// In ru, this message translates to:
  /// **'Снять ограничение в 1 000 000 на операции'**
  String get setPolicyBigAmountDesc;

  /// No description provided for @setPolicyBlockPriceDecrease.
  ///
  /// In ru, this message translates to:
  /// **'Запретить снижение цены ниже карточки'**
  String get setPolicyBlockPriceDecrease;

  /// No description provided for @setPolicyBlockPriceDecreaseDesc.
  ///
  /// In ru, this message translates to:
  /// **'Цену в чеке нельзя установить ниже цены товара'**
  String get setPolicyBlockPriceDecreaseDesc;

  /// No description provided for @printerAutoDetect.
  ///
  /// In ru, this message translates to:
  /// **'Найти принтер'**
  String get printerAutoDetect;

  /// No description provided for @printerAutoDetecting.
  ///
  /// In ru, this message translates to:
  /// **'Поиск принтера…'**
  String get printerAutoDetecting;

  /// No description provided for @printerFound.
  ///
  /// In ru, this message translates to:
  /// **'Найдено: {device}'**
  String printerFound(String device);

  /// No description provided for @printerFoundWithNote.
  ///
  /// In ru, this message translates to:
  /// **'Найдено: {device} — {note}'**
  String printerFoundWithNote(String device, String note);

  /// No description provided for @printerNotFoundAnyPort.
  ///
  /// In ru, this message translates to:
  /// **'Принтер не найден ни на одном порту (USB/serial). Проверьте кабель и питание.'**
  String get printerNotFoundAnyPort;

  /// No description provided for @printerUsbName.
  ///
  /// In ru, this message translates to:
  /// **'USB-принтер'**
  String get printerUsbName;

  /// No description provided for @printerSelectDevice.
  ///
  /// In ru, this message translates to:
  /// **'Выберите принтер'**
  String get printerSelectDevice;

  /// No description provided for @printerNoAccessGroupLp.
  ///
  /// In ru, this message translates to:
  /// **'Узел найден, но нет прав (нужна группа lp)'**
  String get printerNoAccessGroupLp;

  /// No description provided for @printerLabelUsb.
  ///
  /// In ru, this message translates to:
  /// **'USB-принтер ({path})'**
  String printerLabelUsb(String path);

  /// No description provided for @printerLabelSerial.
  ///
  /// In ru, this message translates to:
  /// **'Serial-принтер ({path})'**
  String printerLabelSerial(String path);

  /// No description provided for @printerNoAccessGroupLpHint.
  ///
  /// In ru, this message translates to:
  /// **'Узел найден, но нет прав (нужна группа lp): usermod -aG lp telepos и перезапуск сессии.'**
  String get printerNoAccessGroupLpHint;

  /// No description provided for @printerRawOpenNoPermsHint.
  ///
  /// In ru, this message translates to:
  /// **'Узел {path} найден, но открыть нельзя — нет прав. Добавьте пользователя в группу lp (usermod -aG lp telepos) и перезапустите сессию/приставку.'**
  String printerRawOpenNoPermsHint(String path);

  /// No description provided for @printerNotFoundNoNode.
  ///
  /// In ru, this message translates to:
  /// **'Принтер не найден: нет ни одного char-узла /dev/usb/lp* и USB-serial порта. Проверьте кабель и питание принтера.'**
  String get printerNotFoundNoNode;

  /// No description provided for @ownerOnlyTitle.
  ///
  /// In ru, this message translates to:
  /// **'Доступно только владельцу кассы'**
  String get ownerOnlyTitle;

  /// No description provided for @ownerOnlyDesc.
  ///
  /// In ru, this message translates to:
  /// **'Системные операции (перезагрузка, сброс, драйверы, терминал) доступны только под учётной записью владельца.'**
  String get ownerOnlyDesc;

  /// No description provided for @telegramApiSectionTitle.
  ///
  /// In ru, this message translates to:
  /// **'Приложение Telegram'**
  String get telegramApiSectionTitle;

  /// No description provided for @telegramApiSectionDesc.
  ///
  /// In ru, this message translates to:
  /// **'TelePOS не поставляется с ключами Telegram. Зарегистрируйте приложение на my.telegram.org и введите пару ниже — либо передайте её при сборке через --dart-define.'**
  String get telegramApiSectionDesc;

  /// No description provided for @telegramApiIdLabel.
  ///
  /// In ru, this message translates to:
  /// **'api_id'**
  String get telegramApiIdLabel;

  /// No description provided for @telegramApiHashLabel.
  ///
  /// In ru, this message translates to:
  /// **'api_hash'**
  String get telegramApiHashLabel;

  /// No description provided for @telegramApiSave.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить ключи'**
  String get telegramApiSave;

  /// No description provided for @telegramApiClear.
  ///
  /// In ru, this message translates to:
  /// **'Удалить ключи'**
  String get telegramApiClear;

  /// No description provided for @telegramApiSaved.
  ///
  /// In ru, this message translates to:
  /// **'Ключи Telegram сохранены'**
  String get telegramApiSaved;

  /// No description provided for @telegramApiCleared.
  ///
  /// In ru, this message translates to:
  /// **'Ключи Telegram удалены'**
  String get telegramApiCleared;

  /// No description provided for @telegramApiInvalid.
  ///
  /// In ru, this message translates to:
  /// **'Укажите числовой api_id и непустой api_hash'**
  String get telegramApiInvalid;

  /// No description provided for @telegramApiStatusConfigured.
  ///
  /// In ru, this message translates to:
  /// **'Ключи заданы'**
  String get telegramApiStatusConfigured;

  /// No description provided for @telegramApiStatusMissing.
  ///
  /// In ru, this message translates to:
  /// **'Ключи не заданы'**
  String get telegramApiStatusMissing;

  /// No description provided for @deviceSearchButton.
  ///
  /// In ru, this message translates to:
  /// **'Искать'**
  String get deviceSearchButton;

  /// No description provided for @deviceSearchTitle.
  ///
  /// In ru, this message translates to:
  /// **'Найденные устройства'**
  String get deviceSearchTitle;

  /// No description provided for @deviceSearchRunning.
  ///
  /// In ru, this message translates to:
  /// **'Идёт поиск…'**
  String get deviceSearchRunning;

  /// No description provided for @deviceSearchEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Ничего не найдено. Все источники опрошены — устройство не подключено или выключено.'**
  String get deviceSearchEmpty;

  /// No description provided for @deviceSearchNoValueForField.
  ///
  /// In ru, this message translates to:
  /// **'Устройства найдены, но ни одно не даёт значения для этого поля.'**
  String get deviceSearchNoValueForField;

  /// No description provided for @deviceSearchFailedSources.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось выполнить поиск: {sources}. Это не то же самое, что «ничего не подключено».'**
  String deviceSearchFailedSources(String sources);

  /// No description provided for @deviceSearchUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Поиск устройств недоступен в этой сборке.'**
  String get deviceSearchUnavailable;

  /// No description provided for @deviceSearchFieldFilled.
  ///
  /// In ru, this message translates to:
  /// **'Поле заполнено: {value}'**
  String deviceSearchFieldFilled(String value);

  /// No description provided for @deviceSourceSerialPort.
  ///
  /// In ru, this message translates to:
  /// **'Последовательный порт'**
  String get deviceSourceSerialPort;

  /// No description provided for @deviceSourceUsb.
  ///
  /// In ru, this message translates to:
  /// **'USB'**
  String get deviceSourceUsb;

  /// No description provided for @deviceSourceNetwork.
  ///
  /// In ru, this message translates to:
  /// **'Сеть'**
  String get deviceSourceNetwork;

  /// No description provided for @deviceSourceBluetooth.
  ///
  /// In ru, this message translates to:
  /// **'Bluetooth'**
  String get deviceSourceBluetooth;

  /// No description provided for @deviceCheckButton.
  ///
  /// In ru, this message translates to:
  /// **'Проверить устройство'**
  String get deviceCheckButton;

  /// No description provided for @deviceCheckRunning.
  ///
  /// In ru, this message translates to:
  /// **'Проверка…'**
  String get deviceCheckRunning;

  /// No description provided for @deviceCheckUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Проверка устройств недоступна в этой сборке.'**
  String get deviceCheckUnavailable;

  /// No description provided for @deviceCheckSavedBindingNotice.
  ///
  /// In ru, this message translates to:
  /// **'Проверяется сохранённая привязка: устройство опрашивается по записанным параметрам, а не по несохранённым изменениям на этом экране. Чтобы новая привязка заработала в продажах, перезапустите приложение.'**
  String get deviceCheckSavedBindingNotice;

  /// No description provided for @deviceCheckReasonOk.
  ///
  /// In ru, this message translates to:
  /// **'Устройство ответило'**
  String get deviceCheckReasonOk;

  /// No description provided for @deviceCheckReasonNotConfigured.
  ///
  /// In ru, this message translates to:
  /// **'Устройство не настроено'**
  String get deviceCheckReasonNotConfigured;

  /// No description provided for @deviceCheckReasonInvalidBinding.
  ///
  /// In ru, this message translates to:
  /// **'Привязка некорректна'**
  String get deviceCheckReasonInvalidBinding;

  /// No description provided for @deviceCheckReasonDriverNotLive.
  ///
  /// In ru, this message translates to:
  /// **'Привязка сохранена, но эта сборка не может работать с этим устройством'**
  String get deviceCheckReasonDriverNotLive;

  /// No description provided for @deviceCheckReasonConnectionFailed.
  ///
  /// In ru, this message translates to:
  /// **'Устройство не отвечает'**
  String get deviceCheckReasonConnectionFailed;

  /// No description provided for @deviceCheckReasonDeviceRefused.
  ///
  /// In ru, this message translates to:
  /// **'Устройство отказало в операции'**
  String get deviceCheckReasonDeviceRefused;

  /// No description provided for @deviceCheckReasonNotSupportedOnPlatform.
  ///
  /// In ru, this message translates to:
  /// **'Не поддерживается на этой платформе'**
  String get deviceCheckReasonNotSupportedOnPlatform;

  /// No description provided for @deviceCheckReasonNotImplemented.
  ///
  /// In ru, this message translates to:
  /// **'Проверка для этого класса ещё не реализована'**
  String get deviceCheckReasonNotImplemented;

  /// No description provided for @deviceCheckReasonUnexpectedError.
  ///
  /// In ru, this message translates to:
  /// **'Непредвиденная ошибка'**
  String get deviceCheckReasonUnexpectedError;

  /// No description provided for @scannerRulesTitle.
  ///
  /// In ru, this message translates to:
  /// **'Правила чтения штрихкода'**
  String get scannerRulesTitle;

  /// No description provided for @scannerRulesSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Не свойства сканера, а правила установки: какое прочитанное значение принять.'**
  String get scannerRulesSubtitle;

  /// No description provided for @scannerRulesMinLength.
  ///
  /// In ru, this message translates to:
  /// **'Минимальная длина штрихкода'**
  String get scannerRulesMinLength;

  /// No description provided for @scannerRulesMaxLength.
  ///
  /// In ru, this message translates to:
  /// **'Максимальная длина штрихкода'**
  String get scannerRulesMaxLength;

  /// No description provided for @scannerRulesTimeoutMs.
  ///
  /// In ru, this message translates to:
  /// **'Промежуток между символами сканера, мс'**
  String get scannerRulesTimeoutMs;

  /// No description provided for @scannerRulesDefaultHint.
  ///
  /// In ru, this message translates to:
  /// **'Пусто — по умолчанию {value}'**
  String scannerRulesDefaultHint(String value);

  /// No description provided for @scannerRulesNotAnInteger.
  ///
  /// In ru, this message translates to:
  /// **'Значение «{value}» — не целое число'**
  String scannerRulesNotAnInteger(String value);

  /// No description provided for @scannerRulesSaved.
  ///
  /// In ru, this message translates to:
  /// **'Правила чтения штрихкода сохранены'**
  String get scannerRulesSaved;

  /// No description provided for @printQueueSectionTitle.
  ///
  /// In ru, this message translates to:
  /// **'Очередь печати'**
  String get printQueueSectionTitle;

  /// No description provided for @printQueueSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Что ждёт печати, что не напечаталось и почему.'**
  String get printQueueSubtitle;

  /// No description provided for @printQueueEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Очередь пуста — непечатанных чеков нет.'**
  String get printQueueEmpty;

  /// No description provided for @printQueueUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Очередь печати недоступна в этой сборке.'**
  String get printQueueUnavailable;

  /// No description provided for @printQueueUnreadable.
  ///
  /// In ru, this message translates to:
  /// **'Очередь печати не читается'**
  String get printQueueUnreadable;

  /// No description provided for @printQueueUnreadableHint.
  ///
  /// In ru, this message translates to:
  /// **'Это не пустая очередь: задания могут ждать печати, но список прочитать нельзя. Требуется обслуживание.'**
  String get printQueueUnreadableHint;

  /// No description provided for @printQueueStateQueued.
  ///
  /// In ru, this message translates to:
  /// **'Ждёт печати'**
  String get printQueueStateQueued;

  /// No description provided for @printQueueStatePrinting.
  ///
  /// In ru, this message translates to:
  /// **'Печатается'**
  String get printQueueStatePrinting;

  /// No description provided for @printQueueStatePrinted.
  ///
  /// In ru, this message translates to:
  /// **'Напечатано'**
  String get printQueueStatePrinted;

  /// No description provided for @printQueueStateFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не напечаталось, будет повторено'**
  String get printQueueStateFailed;

  /// No description provided for @printQueueStateExpired.
  ///
  /// In ru, this message translates to:
  /// **'Срок вышел, само повторяться не будет'**
  String get printQueueStateExpired;

  /// No description provided for @printQueueStateCancelled.
  ///
  /// In ru, this message translates to:
  /// **'Отменено оператором'**
  String get printQueueStateCancelled;

  /// No description provided for @printQueueAttempts.
  ///
  /// In ru, this message translates to:
  /// **'Попыток: {count}'**
  String printQueueAttempts(int count);

  /// No description provided for @printQueueDeadline.
  ///
  /// In ru, this message translates to:
  /// **'Срок до {moment}'**
  String printQueueDeadline(String moment);

  /// No description provided for @printQueueReason.
  ///
  /// In ru, this message translates to:
  /// **'Причина: {reason}'**
  String printQueueReason(String reason);

  /// No description provided for @printQueueRetry.
  ///
  /// In ru, this message translates to:
  /// **'Повторить'**
  String get printQueueRetry;

  /// No description provided for @printQueueCancelJob.
  ///
  /// In ru, this message translates to:
  /// **'Отменить задание'**
  String get printQueueCancelJob;

  /// No description provided for @printQueueExtendTitle.
  ///
  /// In ru, this message translates to:
  /// **'На сколько продлить задание?'**
  String get printQueueExtendTitle;

  /// No description provided for @printQueueExtend5Minutes.
  ///
  /// In ru, this message translates to:
  /// **'Ещё 5 минут'**
  String get printQueueExtend5Minutes;

  /// No description provided for @printQueueExtend30Minutes.
  ///
  /// In ru, this message translates to:
  /// **'Ещё 30 минут'**
  String get printQueueExtend30Minutes;

  /// No description provided for @printQueueExtend2Hours.
  ///
  /// In ru, this message translates to:
  /// **'Ещё 2 часа'**
  String get printQueueExtend2Hours;

  /// No description provided for @printQueueRetryAccepted.
  ///
  /// In ru, this message translates to:
  /// **'Задание снова в очереди'**
  String get printQueueRetryAccepted;

  /// No description provided for @printQueueRetryAlreadyPrinted.
  ///
  /// In ru, this message translates to:
  /// **'Этот чек уже напечатан — второй раз он не печатается'**
  String get printQueueRetryAlreadyPrinted;

  /// No description provided for @printQueueRetryRejected.
  ///
  /// In ru, this message translates to:
  /// **'Повторить не удалось'**
  String get printQueueRetryRejected;

  /// No description provided for @printQueueCancelTitle.
  ///
  /// In ru, this message translates to:
  /// **'Отменить задание?'**
  String get printQueueCancelTitle;

  /// No description provided for @printQueueCancelBody.
  ///
  /// In ru, this message translates to:
  /// **'Отменённое задание напечатать уже нельзя. Если такой же чек всё-таки нужен, его придётся выбить заново.'**
  String get printQueueCancelBody;

  /// No description provided for @printQueueCancelConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Отменить задание'**
  String get printQueueCancelConfirm;

  /// No description provided for @printQueueCancelDone.
  ///
  /// In ru, this message translates to:
  /// **'Задание отменено'**
  String get printQueueCancelDone;

  /// No description provided for @printQueueCancelRefused.
  ///
  /// In ru, this message translates to:
  /// **'Это задание отменить уже нельзя: оно печатается или уже завершено'**
  String get printQueueCancelRefused;

  /// No description provided for @errorPayReceiptNotFound.
  ///
  /// In ru, this message translates to:
  /// **'Чек больше не в работе — оплатить его нельзя. Обновите экран и начните заново.'**
  String get errorPayReceiptNotFound;

  /// No description provided for @errorPayNotOwner.
  ///
  /// In ru, this message translates to:
  /// **'Этот чек ведёт другое рабочее место — оплатить его отсюда нельзя.'**
  String get errorPayNotOwner;

  /// No description provided for @errorPaymentAlreadyTaken.
  ///
  /// In ru, this message translates to:
  /// **'Этот чек уже оплачен. Взять деньги второй раз касса не станет.'**
  String get errorPaymentAlreadyTaken;

  /// No description provided for @errorPaymentInsufficient.
  ///
  /// In ru, this message translates to:
  /// **'Названной суммы не хватает на чек. Назовите сумму заново.'**
  String get errorPaymentInsufficient;

  /// No description provided for @errorPaymentAccountMissing.
  ///
  /// In ru, this message translates to:
  /// **'У кассы нет счёта для этого вида оплаты. Обратитесь к администратору.'**
  String get errorPaymentAccountMissing;

  /// No description provided for @errorPaymentAccountNotAllowed.
  ///
  /// In ru, this message translates to:
  /// **'Такой счёт для оплаты не предлагался. Обновите список счетов и выберите заново.'**
  String get errorPaymentAccountNotAllowed;

  /// No description provided for @errorPaymentUnbalanced.
  ///
  /// In ru, this message translates to:
  /// **'Сумма строк оплаты не сходится с суммой чека. Наберите оплату заново.'**
  String get errorPaymentUnbalanced;

  /// No description provided for @errorPaymentKindInactive.
  ///
  /// In ru, this message translates to:
  /// **'Этот вид оплаты выключен в настройках кассы. Выберите другой или включите его в настройках.'**
  String get errorPaymentKindInactive;

  /// No description provided for @errorPaymentKindUnknown.
  ///
  /// In ru, this message translates to:
  /// **'Касса не знает такого вида оплаты. Обратитесь к администратору.'**
  String get errorPaymentKindUnknown;

  /// No description provided for @errorCertificateUnknown.
  ///
  /// In ru, this message translates to:
  /// **'Сертификата с таким номером на этой кассе нет. Проверьте номер.'**
  String get errorCertificateUnknown;

  /// No description provided for @errorCertificatePinWrong.
  ///
  /// In ru, this message translates to:
  /// **'ПИН сертификата не подошёл. Наберите его заново.'**
  String get errorCertificatePinWrong;

  /// No description provided for @errorCertificateRateLimited.
  ///
  /// In ru, this message translates to:
  /// **'Слишком много неудачных проверок сертификата. Подождите несколько минут и повторите.'**
  String get errorCertificateRateLimited;

  /// No description provided for @errorConnectionLost.
  ///
  /// In ru, this message translates to:
  /// **'Связь с кассой потеряна. Проверьте сеть и повторите.'**
  String get errorConnectionLost;

  /// No description provided for @errorRunIncomplete.
  ///
  /// In ru, this message translates to:
  /// **'Касса прервала операцию, не завершив её. Проверьте на кассе результат, прежде чем повторять.'**
  String get errorRunIncomplete;

  /// No description provided for @errorWireMismatch.
  ///
  /// In ru, this message translates to:
  /// **'Рабочее место и касса не поняли друг друга — версии разошлись. Обновите страницу; если не поможет, обратитесь к администратору.'**
  String get errorWireMismatch;

  /// No description provided for @errorTillFailed.
  ///
  /// In ru, this message translates to:
  /// **'Касса не смогла выполнить операцию. Повторите; если ошибка повторится, обратитесь к администратору.'**
  String get errorTillFailed;

  /// No description provided for @errorTerminalChanged.
  ///
  /// In ru, this message translates to:
  /// **'Вы сменили рабочее место — войдите снова.'**
  String get errorTerminalChanged;

  /// No description provided for @errorUnknownTerminal.
  ///
  /// In ru, this message translates to:
  /// **'Рабочее место не привязано к кассе. Привяжите его заново кодом привязки.'**
  String get errorUnknownTerminal;

  /// No description provided for @errorAlreadyConfigured.
  ///
  /// In ru, this message translates to:
  /// **'Касса уже настроена — мастер первичной настройки больше недоступен.'**
  String get errorAlreadyConfigured;

  /// No description provided for @errorCannotDeleteSelf.
  ///
  /// In ru, this message translates to:
  /// **'Нельзя удалить рабочее место самой кассы.'**
  String get errorCannotDeleteSelf;

  /// No description provided for @errorNoDrivers.
  ///
  /// In ru, this message translates to:
  /// **'Касса собрана без драйверов оборудования — поиск и проверка устройств недоступны. Обратитесь к администратору.'**
  String get errorNoDrivers;

  /// No description provided for @errorNoNetworkModule.
  ///
  /// In ru, this message translates to:
  /// **'Эта касса не управляет сетевыми настройками — нет системной службы. Обратитесь к администратору.'**
  String get errorNoNetworkModule;

  /// No description provided for @errorNoSessionRegistry.
  ///
  /// In ru, this message translates to:
  /// **'Эта касса не ведёт список сеансов. Обратитесь к администратору.'**
  String get errorNoSessionRegistry;

  /// No description provided for @errorNoBackupTransport.
  ///
  /// In ru, this message translates to:
  /// **'Резервные копии на этой кассе не настроены. Обратитесь к администратору.'**
  String get errorNoBackupTransport;

  /// No description provided for @errorBackupNotFound.
  ///
  /// In ru, this message translates to:
  /// **'Резервная копия не найдена.'**
  String get errorBackupNotFound;

  /// No description provided for @errorCertificatesUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Эта касса не выпускает подарочные сертификаты по проводу. Обратитесь к администратору.'**
  String get errorCertificatesUnavailable;

  /// No description provided for @errorRefundStale.
  ///
  /// In ru, this message translates to:
  /// **'Возврат изменился, пока команда шла на кассу. Повторите действие.'**
  String get errorRefundStale;

  /// No description provided for @errorRefundWrongDraft.
  ///
  /// In ru, this message translates to:
  /// **'Этого черновика возврата больше нет. Откройте возврат заново.'**
  String get errorRefundWrongDraft;

  /// No description provided for @errorRefundNotStarted.
  ///
  /// In ru, this message translates to:
  /// **'Возврат не начат — выберите чек или начните возврат без чека.'**
  String get errorRefundNotStarted;

  /// No description provided for @errorRefundEmpty.
  ///
  /// In ru, this message translates to:
  /// **'В возврате нет ни одной строки — возвращать нечего.'**
  String get errorRefundEmpty;

  /// No description provided for @errorReceiptAlreadyRefunded.
  ///
  /// In ru, this message translates to:
  /// **'По этому чеку возврат уже сделан.'**
  String get errorReceiptAlreadyRefunded;

  /// No description provided for @errorReceiptNotRefundable.
  ///
  /// In ru, this message translates to:
  /// **'Этот чек нельзя вернуть здесь: оплата прошла через терминал другой кассы. Оформите возврат там, где платили.'**
  String get errorReceiptNotRefundable;

  /// No description provided for @errorLineNotInReceipt.
  ///
  /// In ru, this message translates to:
  /// **'Этого товара нет в чеке — по чеку возвращается только проданное в нём.'**
  String get errorLineNotInReceipt;

  /// No description provided for @errorSaleNotCompleted.
  ///
  /// In ru, this message translates to:
  /// **'Продажа по этому чеку не завершена — возвращать нечего.'**
  String get errorSaleNotCompleted;

  /// No description provided for @errorRefundBusy.
  ///
  /// In ru, this message translates to:
  /// **'На кассе уже идёт другой возврат. Завершите его и повторите.'**
  String get errorRefundBusy;

  /// No description provided for @errorRefundCannotStart.
  ///
  /// In ru, this message translates to:
  /// **'Касса не смогла начать возврат и не назвала причину. Проверьте смену и настройку кассы.'**
  String get errorRefundCannotStart;

  /// No description provided for @errorRefundInstallmentRefused.
  ///
  /// In ru, this message translates to:
  /// **'Чек продан в рассрочку — касса его не возвращает. Расторжение договора оформляет администратор.'**
  String get errorRefundInstallmentRefused;

  /// No description provided for @errorRefundCashlessUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Эти деньги надо вернуть на карту или через QR, а вернуть их нечем: терминал или провайдер не подключён. Наличными из ящика касса такой возврат не выдаёт.'**
  String get errorRefundCashlessUnavailable;

  /// No description provided for @errorRefundCashlessRefused.
  ///
  /// In ru, this message translates to:
  /// **'Банк или провайдер отказал в возврате. Проверьте терминал и повторите — уже возвращённое второй раз не вернётся.'**
  String get errorRefundCashlessRefused;

  /// No description provided for @errorRefundKindNotRefundable.
  ///
  /// In ru, this message translates to:
  /// **'На этот вид оплаты возврат запрещён в справочнике видов оплаты.'**
  String get errorRefundKindNotRefundable;

  /// No description provided for @errorRefundKindUnknown.
  ///
  /// In ru, this message translates to:
  /// **'Чек оплачен видом оплаты, которого нет в справочнике этой кассы. Возврат по нему касса не проводит: чем платили — неизвестно, а наличными за это не выдают.'**
  String get errorRefundKindUnknown;

  /// No description provided for @refundDestinationsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Куда уйдут деньги'**
  String get refundDestinationsTitle;

  /// No description provided for @refundRouteDrawer.
  ///
  /// In ru, this message translates to:
  /// **'Наличными из ящика'**
  String get refundRouteDrawer;

  /// No description provided for @refundRouteCard.
  ///
  /// In ru, this message translates to:
  /// **'На карту через терминал'**
  String get refundRouteCard;

  /// No description provided for @refundRouteManual.
  ///
  /// In ru, this message translates to:
  /// **'Вне кассы — тем же способом, каким платили'**
  String get refundRouteManual;

  /// No description provided for @refundRouteProvider.
  ///
  /// In ru, this message translates to:
  /// **'Через провайдера QR'**
  String get refundRouteProvider;

  /// No description provided for @refundRouteCertificate.
  ///
  /// In ru, this message translates to:
  /// **'Новым сертификатом (старый остаётся погашенным)'**
  String get refundRouteCertificate;

  /// No description provided for @refundRouteAdvance.
  ///
  /// In ru, this message translates to:
  /// **'В аванс покупателя'**
  String get refundRouteAdvance;

  /// No description provided for @refundRouteBonus.
  ///
  /// In ru, this message translates to:
  /// **'На бонусный счёт'**
  String get refundRouteBonus;

  /// No description provided for @refundRouteDebt.
  ///
  /// In ru, this message translates to:
  /// **'В счёт долга покупателя'**
  String get refundRouteDebt;

  /// No description provided for @errorCertificateRefundNoSource.
  ///
  /// In ru, this message translates to:
  /// **'Строка чека возвращается сертификатом, но номера сертификата у неё нет. Возврат по ней касса не проводит: новую бумажку выписать не от чего, а обязательство кассы выросло бы впустую.'**
  String get errorCertificateRefundNoSource;

  /// No description provided for @errorCertificateCashRefundRefused.
  ///
  /// In ru, this message translates to:
  /// **'Наличными за сертификат вернуть нельзя — укажите реквизиты для безналичного возврата.'**
  String get errorCertificateCashRefundRefused;

  /// No description provided for @errorCertificatePaysCertificate.
  ///
  /// In ru, this message translates to:
  /// **'Сертификатом нельзя оплатить покупку другого сертификата.'**
  String get errorCertificatePaysCertificate;

  /// No description provided for @errorCreditContractUnknown.
  ///
  /// In ru, this message translates to:
  /// **'Договора рассрочки с таким номером нет. Проверьте номер.'**
  String get errorCreditContractUnknown;

  /// No description provided for @errorCreditContractNotActive.
  ///
  /// In ru, this message translates to:
  /// **'Договор рассрочки уже погашен или отозван — платить по нему не за что.'**
  String get errorCreditContractNotActive;

  /// No description provided for @errorCreditOverpayment.
  ///
  /// In ru, this message translates to:
  /// **'Сумма больше остатка по договору. Проверьте сумму.'**
  String get errorCreditOverpayment;

  /// No description provided for @errorCreditRepaymentInvalid.
  ///
  /// In ru, this message translates to:
  /// **'Сумма погашения должна быть больше нуля.'**
  String get errorCreditRepaymentInvalid;

  /// No description provided for @errorCreditAllocationRace.
  ///
  /// In ru, this message translates to:
  /// **'По договору в ту же секунду заплатили с другой кассы. Примите платёж заново.'**
  String get errorCreditAllocationRace;

  /// No description provided for @errorKindTenderCannotDiscount.
  ///
  /// In ru, this message translates to:
  /// **'Вид, приносящий живые деньги, нельзя объявить в чеке «не платежом».'**
  String get errorKindTenderCannotDiscount;

  /// No description provided for @errorKindAccountMissing.
  ///
  /// In ru, this message translates to:
  /// **'Виду оплаты не назначен счёт-получатель.'**
  String get errorKindAccountMissing;

  /// No description provided for @errorKindCounterpartyRequired.
  ///
  /// In ru, this message translates to:
  /// **'Отложенный вид оплаты требует названного покупателя.'**
  String get errorKindCounterpartyRequired;

  /// No description provided for @errorKindProviderRequired.
  ///
  /// In ru, this message translates to:
  /// **'Виду оплаты через провайдера (QR) нужен провайдер.'**
  String get errorKindProviderRequired;

  /// No description provided for @errorKindFiscalKindRequired.
  ///
  /// In ru, this message translates to:
  /// **'У вида оплаты не указана фискальная трактовка.'**
  String get errorKindFiscalKindRequired;

  /// No description provided for @errorKindChangeNotATender.
  ///
  /// In ru, this message translates to:
  /// **'Сдачу выдаёт только вид, приносящий живые деньги.'**
  String get errorKindChangeNotATender;

  /// No description provided for @errorKindSystemImmutable.
  ///
  /// In ru, this message translates to:
  /// **'Код или идентификатор системного вида оплаты нельзя менять и нельзя занимать другим видом.'**
  String get errorKindSystemImmutable;

  /// No description provided for @errorCertificateExpired.
  ///
  /// In ru, this message translates to:
  /// **'Срок действия сертификата истёк. Обратитесь к владельцу магазина.'**
  String get errorCertificateExpired;

  /// No description provided for @errorCertificateExhausted.
  ///
  /// In ru, this message translates to:
  /// **'На сертификате не осталось средств.'**
  String get errorCertificateExhausted;

  /// No description provided for @errorCertificateDuplicate.
  ///
  /// In ru, this message translates to:
  /// **'Один и тот же сертификат назван в оплате дважды. Уберите повтор.'**
  String get errorCertificateDuplicate;

  /// No description provided for @errorCertificateRace.
  ///
  /// In ru, this message translates to:
  /// **'Остаток сертификата изменился. Повторите оплату.'**
  String get errorCertificateRace;

  /// No description provided for @errorCertificateAccountMissing.
  ///
  /// In ru, this message translates to:
  /// **'У кассы нет счёта обязательств по сертификатам. Обратитесь к администратору.'**
  String get errorCertificateAccountMissing;

  /// No description provided for @errorCertificateNumberTaken.
  ///
  /// In ru, this message translates to:
  /// **'Сертификат с таким номером уже выпущен.'**
  String get errorCertificateNumberTaken;

  /// No description provided for @errorCertificateNominalInvalid.
  ///
  /// In ru, this message translates to:
  /// **'Номинал сертификата должен быть больше нуля.'**
  String get errorCertificateNominalInvalid;

  /// No description provided for @errorDebtCustomerRequired.
  ///
  /// In ru, this message translates to:
  /// **'Продажа в долг без покупателя невозможна — выберите покупателя.'**
  String get errorDebtCustomerRequired;

  /// No description provided for @errorDebtNotSoldHere.
  ///
  /// In ru, this message translates to:
  /// **'На этой кассе не торгуют в долг — продажа в кредит выключена в настройках кассы.'**
  String get errorDebtNotSoldHere;

  /// No description provided for @errorDebtAccountMissing.
  ///
  /// In ru, this message translates to:
  /// **'У покупателя нет расчётного счёта — долг записать некуда.'**
  String get errorDebtAccountMissing;

  /// No description provided for @errorBonusAccountMissing.
  ///
  /// In ru, this message translates to:
  /// **'У покупателя нет бонусного счёта — списать бонус нечем.'**
  String get errorBonusAccountMissing;

  /// No description provided for @errorPrepaymentCustomerRequired.
  ///
  /// In ru, this message translates to:
  /// **'Зачёт аванса требует покупателя — выберите его.'**
  String get errorPrepaymentCustomerRequired;

  /// No description provided for @errorCreditTermInvalid.
  ///
  /// In ru, this message translates to:
  /// **'Такой срок рассрочки касса не оформляет'**
  String get errorCreditTermInvalid;

  /// No description provided for @errorCreditPrincipalInvalid.
  ///
  /// In ru, this message translates to:
  /// **'Рассрочку не на что оформлять: чек покрыт целиком'**
  String get errorCreditPrincipalInvalid;

  /// No description provided for @errorCreditFeeInvalid.
  ///
  /// In ru, this message translates to:
  /// **'Надбавка по договору задана неверно'**
  String get errorCreditFeeInvalid;

  /// No description provided for @errorCreditSchemeUnknown.
  ///
  /// In ru, this message translates to:
  /// **'Такой схемы графика касса не знает'**
  String get errorCreditSchemeUnknown;

  /// No description provided for @errorCreditOverdue.
  ///
  /// In ru, this message translates to:
  /// **'У покупателя просрочен другой договор рассрочки'**
  String get errorCreditOverdue;

  /// No description provided for @errorCreditContractDuplicate.
  ///
  /// In ru, this message translates to:
  /// **'На этот чек уже оформлен договор рассрочки'**
  String get errorCreditContractDuplicate;

  /// No description provided for @errorPrepaymentAccountMissing.
  ///
  /// In ru, this message translates to:
  /// **'У покупателя нет расчётного счёта — аванса на нём быть не может.'**
  String get errorPrepaymentAccountMissing;

  /// No description provided for @errorPrepaymentInsufficient.
  ///
  /// In ru, this message translates to:
  /// **'Внесённого аванса не хватило: его уже зачли другим чеком.'**
  String get errorPrepaymentInsufficient;

  /// No description provided for @errorLoyaltyCustomerUnknown.
  ///
  /// In ru, this message translates to:
  /// **'Покупатель не найден в картотеке. Выберите покупателя заново.'**
  String get errorLoyaltyCustomerUnknown;

  /// No description provided for @errorAmountExceedsReceipt.
  ///
  /// In ru, this message translates to:
  /// **'Сумма больше стоимости чека. Назовите сумму заново.'**
  String get errorAmountExceedsReceipt;

  /// No description provided for @errorCardChargeUnproven.
  ///
  /// In ru, this message translates to:
  /// **'Касса не подтвердила проведение карты. Проверьте платёжный терминал.'**
  String get errorCardChargeUnproven;

  /// No description provided for @errorPaymentTypeNotAllowed.
  ///
  /// In ru, this message translates to:
  /// **'Этот вид оплаты не разрешён на этом рабочем месте.'**
  String get errorPaymentTypeNotAllowed;

  /// No description provided for @errorPaymentsUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Эта касса не принимает оплату по проводу. Обратитесь к администратору.'**
  String get errorPaymentsUnavailable;

  /// No description provided for @errorNoRefundService.
  ///
  /// In ru, this message translates to:
  /// **'Эта касса не проводит возврат по проводу. Обратитесь к администратору.'**
  String get errorNoRefundService;

  /// No description provided for @errorRefundAbandonIsTillSide.
  ///
  /// In ru, this message translates to:
  /// **'Черновик возврата снимает касса, а не рабочее место.'**
  String get errorRefundAbandonIsTillSide;

  /// No description provided for @errorNoAnswer.
  ///
  /// In ru, this message translates to:
  /// **'Касса не ответила. Проверьте связь и повторите.'**
  String get errorNoAnswer;

  /// No description provided for @paymentTypeNotAllowedHere.
  ///
  /// In ru, this message translates to:
  /// **'«{type}» не разрешена этому рабочему месту. Виды оплаты меняются в настройках оборудования; касса откажет в неразрешённом виде, даже если нажать.'**
  String paymentTypeNotAllowedHere(String type);

  /// No description provided for @paymentTypesLimitedHere.
  ///
  /// In ru, this message translates to:
  /// **'Рабочее место принимает: {types}.'**
  String paymentTypesLimitedHere(String types);

  /// No description provided for @paymentDebtNotSoldHere.
  ///
  /// In ru, this message translates to:
  /// **'На этой кассе в долг не торгуют: продажа в кредит выключена в настройках кассы. Касса откажет, даже если нажать.'**
  String get paymentDebtNotSoldHere;

  /// No description provided for @paymentDebtNotPermitted.
  ///
  /// In ru, this message translates to:
  /// **'Продавать в долг вам не разрешено: нужно право «продажа в долг». Его выдаёт администратор в настройках прав; касса откажет любому, у кого его нет.'**
  String get paymentDebtNotPermitted;

  /// Приёмка 2026-09-17: причина запертого поля скидки в окне правки строки у кассира без права op.sellDiscount. Предел скидки такому кассиру не показывается.
  ///
  /// In ru, this message translates to:
  /// **'Скидку назначать вам не разрешено: нужно право «продажа со скидкой». Его выдаёт администратор в настройках прав; касса откажет любому, у кого его нет.'**
  String get saleDiscountNotPermitted;

  /// No description provided for @paymentDebtPolicyUnknown.
  ///
  /// In ru, this message translates to:
  /// **'Касса пока не ответила, торгуют ли здесь в долг. Проверьте связь с кассой и попробуйте ещё раз.'**
  String get paymentDebtPolicyUnknown;

  /// No description provided for @paymentOffsetsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Аванс и сертификаты'**
  String get paymentOffsetsTitle;

  /// No description provided for @paymentPrepaymentTitle.
  ///
  /// In ru, this message translates to:
  /// **'Аванс покупателя'**
  String get paymentPrepaymentTitle;

  /// No description provided for @paymentPrepaymentNeedsCustomer.
  ///
  /// In ru, this message translates to:
  /// **'Чтобы зачесть аванс, найдите покупателя по номеру телефона.'**
  String get paymentPrepaymentNeedsCustomer;

  /// No description provided for @paymentPrepaymentLoading.
  ///
  /// In ru, this message translates to:
  /// **'Касса ещё не ответила, сколько аванса внесено.'**
  String get paymentPrepaymentLoading;

  /// No description provided for @paymentPrepaymentNone.
  ///
  /// In ru, this message translates to:
  /// **'У покупателя нет внесённого аванса.'**
  String get paymentPrepaymentNone;

  /// No description provided for @paymentPrepaymentBalance.
  ///
  /// In ru, this message translates to:
  /// **'Внесено вперёд:'**
  String get paymentPrepaymentBalance;

  /// No description provided for @paymentPrepaymentUse.
  ///
  /// In ru, this message translates to:
  /// **'Зачесть аванс'**
  String get paymentPrepaymentUse;

  /// No description provided for @paymentPrepaymentApplied.
  ///
  /// In ru, this message translates to:
  /// **'Будет зачтено: {amount}'**
  String paymentPrepaymentApplied(String amount);

  /// No description provided for @paymentCertificateTitle.
  ///
  /// In ru, this message translates to:
  /// **'Подарочный сертификат'**
  String get paymentCertificateTitle;

  /// No description provided for @paymentCertificateNumber.
  ///
  /// In ru, this message translates to:
  /// **'Номер сертификата'**
  String get paymentCertificateNumber;

  /// No description provided for @paymentCertificatePin.
  ///
  /// In ru, this message translates to:
  /// **'ПИН, если есть'**
  String get paymentCertificatePin;

  /// No description provided for @paymentCertificatePresent.
  ///
  /// In ru, this message translates to:
  /// **'Проверить'**
  String get paymentCertificatePresent;

  /// No description provided for @paymentCertificateBalance.
  ///
  /// In ru, this message translates to:
  /// **'Остаток на сертификате: {amount}'**
  String paymentCertificateBalance(String amount);

  /// No description provided for @paymentCertificateApplied.
  ///
  /// In ru, this message translates to:
  /// **'Спишется {amount}, останется {rest}'**
  String paymentCertificateApplied(String amount, String rest);

  /// No description provided for @paymentCertificateNotNeeded.
  ///
  /// In ru, this message translates to:
  /// **'Чек уже покрыт — этот сертификат не понадобится.'**
  String get paymentCertificateNotNeeded;

  /// No description provided for @unfiscalizedTitle.
  ///
  /// In ru, this message translates to:
  /// **'Нефискализованные чеки'**
  String get unfiscalizedTitle;

  /// No description provided for @unfiscalizedEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Все чеки фискализованы'**
  String get unfiscalizedEmpty;

  /// No description provided for @unfiscalizedEmptyHint.
  ///
  /// In ru, this message translates to:
  /// **'Здесь появятся чеки, за которые деньги взяты, а документа оператор не выдал'**
  String get unfiscalizedEmptyHint;

  /// No description provided for @unfiscalizedReceiptNo.
  ///
  /// In ru, this message translates to:
  /// **'Чек №{number}'**
  String unfiscalizedReceiptNo(int number);

  /// No description provided for @unfiscalizedAgeHours.
  ///
  /// In ru, this message translates to:
  /// **'{hours} ч назад'**
  String unfiscalizedAgeHours(int hours);

  /// No description provided for @unfiscalizedOverdue.
  ///
  /// In ru, this message translates to:
  /// **'Просрочено окно 72 ч'**
  String get unfiscalizedOverdue;

  /// No description provided for @unfiscalizedRetry.
  ///
  /// In ru, this message translates to:
  /// **'Повторить'**
  String get unfiscalizedRetry;

  /// No description provided for @unfiscalizedRetryDone.
  ///
  /// In ru, this message translates to:
  /// **'Документ получен: {sign}'**
  String unfiscalizedRetryDone(String sign);

  /// No description provided for @unfiscalizedRetryFailed.
  ///
  /// In ru, this message translates to:
  /// **'Оператор снова отказал: {message}'**
  String unfiscalizedRetryFailed(String message);

  /// No description provided for @unfiscalizedNoDocument.
  ///
  /// In ru, this message translates to:
  /// **'Строка записана до того, как отказы стали нести документ: повторять нечем, её можно только списать'**
  String get unfiscalizedNoDocument;

  /// No description provided for @unfiscalizedNoOperator.
  ///
  /// In ru, this message translates to:
  /// **'Фискальный оператор не настроен: повторять некуда'**
  String get unfiscalizedNoOperator;

  /// No description provided for @unfiscalizedWriteOff.
  ///
  /// In ru, this message translates to:
  /// **'Списать'**
  String get unfiscalizedWriteOff;

  /// No description provided for @unfiscalizedWriteOffTitle.
  ///
  /// In ru, this message translates to:
  /// **'Списать нефискализованный чек'**
  String get unfiscalizedWriteOffTitle;

  /// No description provided for @unfiscalizedWriteOffBy.
  ///
  /// In ru, this message translates to:
  /// **'Решение записывается на имя: {name}'**
  String unfiscalizedWriteOffBy(String name);

  /// No description provided for @unfiscalizedWriteOffReason.
  ///
  /// In ru, this message translates to:
  /// **'Причина списания'**
  String get unfiscalizedWriteOffReason;

  /// No description provided for @unfiscalizedWriteOffDone.
  ///
  /// In ru, this message translates to:
  /// **'Чек помечен разобранным'**
  String get unfiscalizedWriteOffDone;

  /// No description provided for @unfiscalizedWrittenOff.
  ///
  /// In ru, this message translates to:
  /// **'Списал {name}: {reason}'**
  String unfiscalizedWrittenOff(String name, String reason);

  /// No description provided for @unfiscalizedUnknownUser.
  ///
  /// In ru, this message translates to:
  /// **'неизвестный пользователь'**
  String get unfiscalizedUnknownUser;

  /// No description provided for @unfiscalizedAtShiftClose.
  ///
  /// In ru, this message translates to:
  /// **'Смена закрыта с нефискализованными чеками: {count}. Номера: {numbers}'**
  String unfiscalizedAtShiftClose(int count, String numbers);

  /// Ревизия 2026-09-19, дыра 1: Z-отчёт не обгоняет документы своей смены (ShiftService.onCloseShift). Ждущие строки очереди названы кассиру ДО нажатия «Закрыть», когда он ещё может подождать связи.
  ///
  /// In ru, this message translates to:
  /// **'Документы смены ещё не у оператора: {count} (чеки {numbers}). Закрытие дождётся их отправки; если связь не вернётся, Z-отчёт не уйдёт — иначе отчёт оператора разойдётся с кассой.'**
  String documentsOnTheWayAtShiftClose(int count, String numbers);

  /// No description provided for @qrPaidPartial.
  ///
  /// In ru, this message translates to:
  /// **'Оплачено частично: {paid} из {amount}'**
  String qrPaidPartial(String paid, String amount);

  /// No description provided for @qrOrphanTitle.
  ///
  /// In ru, this message translates to:
  /// **'Деньги без чека'**
  String get qrOrphanTitle;

  /// No description provided for @qrOrphanHint.
  ///
  /// In ru, this message translates to:
  /// **'Покупатель заплатил по QR, а чек этими деньгами не закрыт.'**
  String get qrOrphanHint;

  /// No description provided for @qrOrphanLine.
  ///
  /// In ru, this message translates to:
  /// **'{amount} · {provider} · {key}'**
  String qrOrphanLine(String amount, String provider, String key);

  /// No description provided for @qrOrphanAfterGiveUp.
  ///
  /// In ru, this message translates to:
  /// **'Подтверждение пришло после того, как касса перестала ждать'**
  String get qrOrphanAfterGiveUp;

  /// No description provided for @errorQrIntentUnknown.
  ///
  /// In ru, this message translates to:
  /// **'Касса не знает этой оплаты по QR. Обновите чек и повторите.'**
  String get errorQrIntentUnknown;

  /// No description provided for @errorQrIntentNotPaid.
  ///
  /// In ru, this message translates to:
  /// **'Оплата по QR ещё не подтверждена банком. Дождитесь подтверждения или выберите другой способ.'**
  String get errorQrIntentNotPaid;

  /// No description provided for @errorQrIntentAlreadySettled.
  ///
  /// In ru, this message translates to:
  /// **'Эти деньги уже закрыли другой чек: {message}'**
  String errorQrIntentAlreadySettled(String message);

  /// No description provided for @paymentQrTitle.
  ///
  /// In ru, this message translates to:
  /// **'Оплата по QR'**
  String get paymentQrTitle;

  /// No description provided for @paymentQrAmount.
  ///
  /// In ru, this message translates to:
  /// **'Сумма по QR'**
  String get paymentQrAmount;

  /// No description provided for @paymentQrStart.
  ///
  /// In ru, this message translates to:
  /// **'Показать QR'**
  String get paymentQrStart;

  /// No description provided for @paymentQrWaiting.
  ///
  /// In ru, this message translates to:
  /// **'Ждём оплату · осталось {seconds} с'**
  String paymentQrWaiting(int seconds);

  /// No description provided for @paymentQrScanHint.
  ///
  /// In ru, this message translates to:
  /// **'Покупатель сканирует код в приложении банка'**
  String get paymentQrScanHint;

  /// No description provided for @paymentQrCancel.
  ///
  /// In ru, this message translates to:
  /// **'Отменить ожидание'**
  String get paymentQrCancel;

  /// No description provided for @paymentQrNoLink.
  ///
  /// In ru, this message translates to:
  /// **'Нет связи с провайдером — касса повторяет запрос сама'**
  String get paymentQrNoLink;

  /// No description provided for @paymentQrPaid.
  ///
  /// In ru, this message translates to:
  /// **'Оплачено по QR: {amount}'**
  String paymentQrPaid(String amount);

  /// No description provided for @paymentQrPaidAfterCancel.
  ///
  /// In ru, this message translates to:
  /// **'Покупатель успел оплатить до отмены — {amount} идёт в этот чек'**
  String paymentQrPaidAfterCancel(String amount);

  /// No description provided for @paymentQrCancelled.
  ///
  /// In ru, this message translates to:
  /// **'Ожидание отменено, провайдер отмену подтвердил'**
  String get paymentQrCancelled;

  /// No description provided for @paymentQrPatienceSpent.
  ///
  /// In ru, this message translates to:
  /// **'Покупатель не оплатил за отведённое время — касса перестала ждать'**
  String get paymentQrPatienceSpent;

  /// No description provided for @paymentQrExpired.
  ///
  /// In ru, this message translates to:
  /// **'Срок QR-кода вышел у провайдера'**
  String get paymentQrExpired;

  /// No description provided for @paymentQrFailed.
  ///
  /// In ru, this message translates to:
  /// **'Провайдер отказал в оплате по QR'**
  String get paymentQrFailed;

  /// No description provided for @paymentQrCancelUnconfirmed.
  ///
  /// In ru, this message translates to:
  /// **'Отмена не подтверждена — деньги ещё могут прийти. Не принимайте другую оплату, пока касса не выяснит.'**
  String get paymentQrCancelUnconfirmed;

  /// No description provided for @paymentQrRecheck.
  ///
  /// In ru, this message translates to:
  /// **'Проверить снова'**
  String get paymentQrRecheck;

  /// No description provided for @paymentQrRestart.
  ///
  /// In ru, this message translates to:
  /// **'Новый код'**
  String get paymentQrRestart;

  /// No description provided for @paymentQrOverReceipt.
  ///
  /// In ru, this message translates to:
  /// **'В чек не помещается {amount} из оплаченного по QR'**
  String paymentQrOverReceipt(String amount);

  /// No description provided for @paymentQrNothingToPay.
  ///
  /// In ru, this message translates to:
  /// **'Чек уже покрыт — показывать код не на что'**
  String get paymentQrNothingToPay;

  /// No description provided for @errorQrNotConfigured.
  ///
  /// In ru, this message translates to:
  /// **'Провайдер QR не настроен на кассе'**
  String get errorQrNotConfigured;

  /// No description provided for @errorQrNetwork.
  ///
  /// In ru, this message translates to:
  /// **'Нет связи с провайдером QR'**
  String get errorQrNetwork;

  /// No description provided for @errorQrTimeout.
  ///
  /// In ru, this message translates to:
  /// **'Провайдер QR не ответил вовремя'**
  String get errorQrTimeout;

  /// No description provided for @errorQrProviderBusy.
  ///
  /// In ru, this message translates to:
  /// **'Провайдер QR занят — касса повторит запрос'**
  String get errorQrProviderBusy;

  /// No description provided for @errorQrMalformedReply.
  ///
  /// In ru, this message translates to:
  /// **'Провайдер QR ответил непонятно — обратитесь к администратору кассы'**
  String get errorQrMalformedReply;

  /// No description provided for @errorQrUnknownIntent.
  ///
  /// In ru, this message translates to:
  /// **'Провайдер QR не знает этой оплаты'**
  String get errorQrUnknownIntent;

  /// No description provided for @errorQrRejected.
  ///
  /// In ru, this message translates to:
  /// **'Провайдер QR отклонил запрос'**
  String get errorQrRejected;

  /// No description provided for @errorQrReverseUnsupported.
  ///
  /// In ru, this message translates to:
  /// **'Провайдер QR не умеет возвращать деньги'**
  String get errorQrReverseUnsupported;

  /// No description provided for @errorQrIntentLive.
  ///
  /// In ru, this message translates to:
  /// **'На этом чеке уже ждёт оплата по QR — отмените её, прежде чем показывать новый код'**
  String get errorQrIntentLive;

  /// No description provided for @fiscalReasonNetwork.
  ///
  /// In ru, this message translates to:
  /// **'Нет связи с фискальным оператором'**
  String get fiscalReasonNetwork;

  /// No description provided for @fiscalReasonOperatorUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Фискальный оператор недоступен'**
  String get fiscalReasonOperatorUnavailable;

  /// No description provided for @fiscalReasonTokenExpired.
  ///
  /// In ru, this message translates to:
  /// **'Оператор не принял авторизацию кассы'**
  String get fiscalReasonTokenExpired;

  /// No description provided for @fiscalReasonRequestNotBuilt.
  ///
  /// In ru, this message translates to:
  /// **'Запрос к оператору не собран: проверьте адрес сервера в фискальных настройках'**
  String get fiscalReasonRequestNotBuilt;

  /// No description provided for @fiscalReasonTlsRejected.
  ///
  /// In ru, this message translates to:
  /// **'Защищённое соединение с оператором не установлено: проверьте адрес сервера и часы кассы'**
  String get fiscalReasonTlsRejected;

  /// No description provided for @fiscalReasonClientFault.
  ///
  /// In ru, this message translates to:
  /// **'Сбой кассы при обмене с оператором'**
  String get fiscalReasonClientFault;

  /// No description provided for @fiscalReasonBadCredentials.
  ///
  /// In ru, this message translates to:
  /// **'Неверный логин или пароль оператора'**
  String get fiscalReasonBadCredentials;

  /// No description provided for @fiscalReasonCashboxNotFound.
  ///
  /// In ru, this message translates to:
  /// **'Касса не найдена у оператора: проверьте заводской номер'**
  String get fiscalReasonCashboxNotFound;

  /// No description provided for @fiscalReasonCashboxBlocked.
  ///
  /// In ru, this message translates to:
  /// **'Касса заблокирована оператором'**
  String get fiscalReasonCashboxBlocked;

  /// No description provided for @fiscalReasonOfflineLimitExceeded.
  ///
  /// In ru, this message translates to:
  /// **'Превышен лимит автономных документов'**
  String get fiscalReasonOfflineLimitExceeded;

  /// No description provided for @fiscalReasonOfflineNotSupported.
  ///
  /// In ru, this message translates to:
  /// **'Автономный режим этой кассе не разрешён'**
  String get fiscalReasonOfflineNotSupported;

  /// No description provided for @fiscalReasonDuplicate.
  ///
  /// In ru, this message translates to:
  /// **'Документ уже зарегистрирован у оператора, фискальный признак кассе не выдан — возьмите его в кабинете оператора'**
  String get fiscalReasonDuplicate;

  /// No description provided for @fiscalReasonValidation.
  ///
  /// In ru, this message translates to:
  /// **'Оператор отклонил документ: суммы или данные не сходятся'**
  String get fiscalReasonValidation;

  /// No description provided for @fiscalReasonNotEnoughMoney.
  ///
  /// In ru, this message translates to:
  /// **'По данным оператора в кассе недостаточно наличных'**
  String get fiscalReasonNotEnoughMoney;

  /// No description provided for @fiscalReasonShiftError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка смены у оператора'**
  String get fiscalReasonShiftError;

  /// No description provided for @fiscalReasonUnsupported.
  ///
  /// In ru, this message translates to:
  /// **'Операция не поддерживается оператором'**
  String get fiscalReasonUnsupported;

  /// No description provided for @fiscalReasonNotConfigured.
  ///
  /// In ru, this message translates to:
  /// **'Фискализация не настроена'**
  String get fiscalReasonNotConfigured;

  /// No description provided for @fiscalReasonUnknown.
  ///
  /// In ru, this message translates to:
  /// **'Оператор отказал по неизвестной причине'**
  String get fiscalReasonUnknown;

  /// No description provided for @fiscalReasonOfflineWindowExpired.
  ///
  /// In ru, this message translates to:
  /// **'Истекло автономное окно 72 ч — документ не выдан'**
  String get fiscalReasonOfflineWindowExpired;

  /// No description provided for @fiscalReasonRowUnreadable.
  ///
  /// In ru, this message translates to:
  /// **'Строка очереди повреждена: документ не читается'**
  String get fiscalReasonRowUnreadable;

  /// Причина фискального отказа с кодом оператора (у «оператор недоступен» — HTTP-статус)
  ///
  /// In ru, this message translates to:
  /// **'{reason} (код {code})'**
  String fiscalReasonWithCode(String reason, int code);

  /// Строка очереди, записанная русским текстом до перевода причин
  ///
  /// In ru, this message translates to:
  /// **'Причина записана до перевода: {text}'**
  String fiscalReasonLegacy(String text);

  /// No description provided for @fiscalReasonNotRecorded.
  ///
  /// In ru, this message translates to:
  /// **'Причина не записана'**
  String get fiscalReasonNotRecorded;

  /// No description provided for @fiscalReasonPaymentTypeNotAccepted.
  ///
  /// In ru, this message translates to:
  /// **'Вид оплаты не принимается оператором: «кредит» и «тара» исключены протоколом ОФД 2.0.2'**
  String get fiscalReasonPaymentTypeNotAccepted;

  /// No description provided for @errorDeferredListUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Список отложенных чеков недоступен'**
  String get errorDeferredListUnavailable;

  /// No description provided for @errorDeferredListUnavailableReason.
  ///
  /// In ru, this message translates to:
  /// **'Список отложенных чеков недоступен: {reason}'**
  String errorDeferredListUnavailableReason(String reason);

  /// No description provided for @errorRefundSearchUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Поиск товара для возврата на этом терминале ещё не подключён'**
  String get errorRefundSearchUnavailable;

  /// No description provided for @errorRefundNothingSelected.
  ///
  /// In ru, this message translates to:
  /// **'Черновик изменился — возвращать нечего. Проверьте выделенные строки.'**
  String get errorRefundNothingSelected;

  /// No description provided for @errorRefundInvalidAmount.
  ///
  /// In ru, this message translates to:
  /// **'Столько вернуть нельзя: количество не может быть больше проданного по чеку или меньше нуля.'**
  String get errorRefundInvalidAmount;

  /// No description provided for @errorCertificatePinRequired.
  ///
  /// In ru, this message translates to:
  /// **'У сертификата есть ПИН. Наберите ПИН с сертификата.'**
  String get errorCertificatePinRequired;

  /// No description provided for @qrSettingsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Оплата по QR'**
  String get qrSettingsTitle;

  /// No description provided for @qrSettingsSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Провайдер QR/СБП: адрес, код, ключ, ожидание'**
  String get qrSettingsSubtitle;

  /// No description provided for @qrSettingsKindTitle.
  ///
  /// In ru, this message translates to:
  /// **'Принимать оплату по QR'**
  String get qrSettingsKindTitle;

  /// No description provided for @qrSettingsKindSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Вид оплаты «QR» на экране оплаты'**
  String get qrSettingsKindSubtitle;

  /// No description provided for @qrSettingsUrl.
  ///
  /// In ru, this message translates to:
  /// **'Адрес провайдера'**
  String get qrSettingsUrl;

  /// No description provided for @qrSettingsCode.
  ///
  /// In ru, this message translates to:
  /// **'Код провайдера'**
  String get qrSettingsCode;

  /// No description provided for @qrSettingsKey.
  ///
  /// In ru, this message translates to:
  /// **'Ключ доступа'**
  String get qrSettingsKey;

  /// No description provided for @qrSettingsKeyStoredHint.
  ///
  /// In ru, this message translates to:
  /// **'Ключ сохранён. Введите новый, чтобы заменить'**
  String get qrSettingsKeyStoredHint;

  /// No description provided for @qrSettingsKeyEmptyHint.
  ///
  /// In ru, this message translates to:
  /// **'Ключ не задан'**
  String get qrSettingsKeyEmptyHint;

  /// No description provided for @qrSettingsClearKey.
  ///
  /// In ru, this message translates to:
  /// **'Стереть сохранённый ключ'**
  String get qrSettingsClearKey;

  /// No description provided for @qrSettingsPatience.
  ///
  /// In ru, this message translates to:
  /// **'Ожидание оплаты, секунд'**
  String get qrSettingsPatience;

  /// No description provided for @qrSettingsSave.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить'**
  String get qrSettingsSave;

  /// No description provided for @qrSettingsSaved.
  ///
  /// In ru, this message translates to:
  /// **'Настройка QR сохранена'**
  String get qrSettingsSaved;

  /// No description provided for @qrSettingsRemove.
  ///
  /// In ru, this message translates to:
  /// **'Снять настройку'**
  String get qrSettingsRemove;

  /// No description provided for @qrSettingsStatusReady.
  ///
  /// In ru, this message translates to:
  /// **'Провайдер настроен'**
  String get qrSettingsStatusReady;

  /// No description provided for @qrSettingsStatusNotConfigured.
  ///
  /// In ru, this message translates to:
  /// **'Провайдер не настроен — оплата по QR недоступна'**
  String get qrSettingsStatusNotConfigured;

  /// No description provided for @qrSettingsInvalidUrl.
  ///
  /// In ru, this message translates to:
  /// **'Адрес должен начинаться с http:// или https://'**
  String get qrSettingsInvalidUrl;

  /// No description provided for @qrSettingsCodeRequired.
  ///
  /// In ru, this message translates to:
  /// **'Укажите код провайдера'**
  String get qrSettingsCodeRequired;

  /// No description provided for @qrSettingsInvalidPatience.
  ///
  /// In ru, this message translates to:
  /// **'Ожидание — от {min} до {max} секунд'**
  String qrSettingsInvalidPatience(String min, String max);

  /// No description provided for @qrSettingsSaveFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось сохранить настройку QR'**
  String get qrSettingsSaveFailed;

  /// No description provided for @qrSettingsTillOnly.
  ///
  /// In ru, this message translates to:
  /// **'Настройка провайдера QR доступна только на самой кассе'**
  String get qrSettingsTillOnly;

  /// No description provided for @installmentTermsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Рассрочка'**
  String get installmentTermsTitle;

  /// No description provided for @installmentTermsMonths.
  ///
  /// In ru, this message translates to:
  /// **'Срок, месяцев'**
  String get installmentTermsMonths;

  /// No description provided for @installmentTermsScheme.
  ///
  /// In ru, this message translates to:
  /// **'Схема графика'**
  String get installmentTermsScheme;

  /// No description provided for @installmentTermsContinue.
  ///
  /// In ru, this message translates to:
  /// **'Продолжить'**
  String get installmentTermsContinue;

  /// No description provided for @customerPaymentTitle.
  ///
  /// In ru, this message translates to:
  /// **'Принять оплату / погасить долг'**
  String get customerPaymentTitle;

  /// No description provided for @customerPaymentCurrentDebt.
  ///
  /// In ru, this message translates to:
  /// **'Текущий долг: {amount}'**
  String customerPaymentCurrentDebt(String amount);

  /// No description provided for @customerPaymentBalance.
  ///
  /// In ru, this message translates to:
  /// **'Баланс: {amount}'**
  String customerPaymentBalance(String amount);

  /// No description provided for @customerPaymentAmount.
  ///
  /// In ru, this message translates to:
  /// **'Сумма оплаты'**
  String get customerPaymentAmount;

  /// No description provided for @customerPaymentAmountInvalid.
  ///
  /// In ru, this message translates to:
  /// **'Введите сумму больше 0'**
  String get customerPaymentAmountInvalid;

  /// No description provided for @customerPaymentFailed.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка проведения оплаты'**
  String get customerPaymentFailed;

  /// No description provided for @customerPaymentSubmit.
  ///
  /// In ru, this message translates to:
  /// **'Принять оплату'**
  String get customerPaymentSubmit;

  /// No description provided for @errorPrepaymentAmountInvalid.
  ///
  /// In ru, this message translates to:
  /// **'Сумма аванса должна быть больше нуля. Наберите сумму заново.'**
  String get errorPrepaymentAmountInvalid;

  /// No description provided for @errorPrepaymentTenderInvalid.
  ///
  /// In ru, this message translates to:
  /// **'Аванс принимается наличными, картой или по QR. Выберите другой вид оплаты.'**
  String get errorPrepaymentTenderInvalid;

  /// Приём аванса отказан: у кассы нет счёта, куда лечь принятым деньгам (наличные — счёт кассы, безнал — эквайринг). Отказ идёт до первой записи.
  ///
  /// In ru, this message translates to:
  /// **'У кассы нет счёта для приёма этого вида оплаты. Настройте счёт приёма и повторите.'**
  String get errorPrepaymentTillAccountMissing;

  /// No description provided for @errorPrepaymentIntakeFailed.
  ///
  /// In ru, this message translates to:
  /// **'Аванс принять не удалось. Проверьте покупателя и повторите.'**
  String get errorPrepaymentIntakeFailed;

  /// No description provided for @errorPrepaymentRefundExceedsBalance.
  ///
  /// In ru, this message translates to:
  /// **'Аванса на счёте покупателя меньше, чем вы выдаёте. Проверьте остаток и убавьте сумму.'**
  String get errorPrepaymentRefundExceedsBalance;

  /// Выдача аванса по проводу отказана до первой записи: кадр пришёл без ключа повтора. Исполнить его значило бы выдать живые деньги, повтор которых опознать будет нечем (решение заказчика 2026-09-18).
  ///
  /// In ru, this message translates to:
  /// **'В заявке на выдачу аванса нет ключа повтора — касса не отличит повтор от второй выдачи. Откройте экран заново и наберите сумму ещё раз.'**
  String get errorPrepaymentRefundKeyMissing;

  /// No description provided for @errorPrepaymentRefundFailed.
  ///
  /// In ru, this message translates to:
  /// **'Аванс выдать не удалось. Проверьте покупателя и повторите.'**
  String get errorPrepaymentRefundFailed;

  /// No description provided for @errorPrepaymentRefundUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Эта касса не выдаёт аванс покупателя по проводу. Обратитесь к администратору.'**
  String get errorPrepaymentRefundUnavailable;

  /// No description provided for @errorPrepaymentIntakeUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Эта касса не принимает аванс покупателя по проводу. Обратитесь к администратору.'**
  String get errorPrepaymentIntakeUnavailable;

  /// Приём аванса отказан до первой записи: кадр пришёл без ключа повтора. Принять его значило бы принять деньги, повтор которых опознать будет нечем (дефект живой приёмки 2026-09-18).
  ///
  /// In ru, this message translates to:
  /// **'В заявке на приём аванса нет ключа повтора — касса не отличит повтор от второго взноса. Откройте экран заново и наберите сумму ещё раз.'**
  String get errorPrepaymentIntakeKeyMissing;

  /// No description provided for @errorQrSetupUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Эта касса не хранит настройку провайдера QR. Настройте оплату по QR на самой кассе или обратитесь к администратору.'**
  String get errorQrSetupUnavailable;

  /// Экран шаблона чека отказан: у кассы нет ни базы шаблонов, ни очереди печати, из байтов которой собирается предпросмотр. Отвечать «сохранено» такой кассе нельзя — владелец ушёл бы, считая чек настроенным.
  ///
  /// In ru, this message translates to:
  /// **'Эта касса не хранит шаблонов чека. Настройте шаблон на самой кассе или обратитесь к администратору.'**
  String get errorReceiptTemplatesUnavailable;

  /// Шаблон отказан до записи: пришёл без названия. Безымянная строка в списке неотличима от строки, которую забыли отрисовать, — владелец решил бы, что шаблон пропал.
  ///
  /// In ru, this message translates to:
  /// **'У шаблона чека обязано быть название. Наберите его и сохраните ещё раз.'**
  String get errorReceiptTemplateNameless;

  /// No description provided for @shiftDeskTitle.
  ///
  /// In ru, this message translates to:
  /// **'Смена'**
  String get shiftDeskTitle;

  /// Окно просроченной смены на браузерном терминале — то же правило, которым касса запирает продажу (ShiftAgeRule, сутки, сравнение >=). С 2026-09-18 рядом стоит рабочая кнопка закрытия, а не только слова.
  ///
  /// In ru, this message translates to:
  /// **'Смена открыта более 24 часов — продажа заблокирована. Закройте её и откройте новую.'**
  String get shiftDeskOverAgeWarning;

  /// Время открытия смены. Приходит с кассы в СЕКУНДАХ эпохи (ShiftDeskView.openedAtSeconds) — множитель 1000 стоит только здесь, на показе.
  ///
  /// In ru, this message translates to:
  /// **'Открыта: {when}'**
  String shiftDeskOpenedAt(String when);

  /// No description provided for @shiftDeskCountedLabel.
  ///
  /// In ru, this message translates to:
  /// **'Пересчитано в ящике'**
  String get shiftDeskCountedLabel;

  /// Пустое поле означает «не считали», а не ноль: ноль в ящике — законный результат пересчёта, и подменить им «не считали» значило бы записать недостачу на всю выручку смены.
  ///
  /// In ru, this message translates to:
  /// **'Оставьте пустым, если не пересчитывали — касса возьмёт свой итог.'**
  String get shiftDeskCountedHint;

  /// No description provided for @shiftDeskOpeningCashLabel.
  ///
  /// In ru, this message translates to:
  /// **'Деньги в ящике на начало'**
  String get shiftDeskOpeningCashLabel;

  /// No description provided for @shiftDeskClosedNow.
  ///
  /// In ru, this message translates to:
  /// **'Смена закрыта.'**
  String get shiftDeskClosedNow;

  /// No description provided for @shiftDeskOpenedNow.
  ///
  /// In ru, this message translates to:
  /// **'Смена открыта.'**
  String get shiftDeskOpenedNow;

  /// No description provided for @shiftDeskNoShift.
  ///
  /// In ru, this message translates to:
  /// **'На кассе нет открытой смены.'**
  String get shiftDeskNoShift;

  /// Смену закрыть можно, но не молча (докстринг ShiftService.unfiscalizedAtClose): запрещать хуже беды, промолчать нельзя.
  ///
  /// In ru, this message translates to:
  /// **'Чеков без фискального документа: {count}'**
  String shiftDeskUnfiscalizedCount(int count);

  /// No description provided for @shiftDeskUnfinishedCount.
  ///
  /// In ru, this message translates to:
  /// **'Незаконченных чеков: {count} — закрытие их приберёт'**
  String shiftDeskUnfinishedCount(int count);

  /// Названный отказ вместо молчаливого успеха: ShiftServiceImpl.onCloseShift без открытой смены пишет предупреждение в журнал и возвращается, и по проводу это прочлось бы как «закрыл».
  ///
  /// In ru, this message translates to:
  /// **'На этой кассе нет открытой смены — закрывать нечего.'**
  String get errorShiftDeskNotOpen;

  /// No description provided for @errorShiftDeskAlreadyOpen.
  ///
  /// In ru, this message translates to:
  /// **'На этой кассе уже открыта смена.'**
  String get errorShiftDeskAlreadyOpen;

  /// No description provided for @errorShiftDeskUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Эта касса не ведёт смен по проводу. Закройте смену на самой кассе или обратитесь к администратору.'**
  String get errorShiftDeskUnavailable;

  /// Кассир берётся из сеанса, никогда из тела кадра (И162): именем смены подписан Z-отчёт и вся её выручка.
  ///
  /// In ru, this message translates to:
  /// **'Смену открывает кассир, а этой заявке кассира назвать нечем. Войдите заново.'**
  String get errorShiftDeskActorUnknown;

  /// No description provided for @prepaymentIntakeTitle.
  ///
  /// In ru, this message translates to:
  /// **'Приём аванса'**
  String get prepaymentIntakeTitle;

  /// No description provided for @prepaymentIntakeFind.
  ///
  /// In ru, this message translates to:
  /// **'Найти покупателя'**
  String get prepaymentIntakeFind;

  /// No description provided for @prepaymentIntakeNotFound.
  ///
  /// In ru, this message translates to:
  /// **'Покупатель с таким номером не найден.'**
  String get prepaymentIntakeNotFound;

  /// No description provided for @prepaymentIntakeSubmit.
  ///
  /// In ru, this message translates to:
  /// **'Принять аванс'**
  String get prepaymentIntakeSubmit;

  /// No description provided for @prepaymentIntakeAccepted.
  ///
  /// In ru, this message translates to:
  /// **'Аванс принят. Внесено вперёд: {amount}'**
  String prepaymentIntakeAccepted(String amount);

  /// No description provided for @prepaymentIntakeFiscalFailed.
  ///
  /// In ru, this message translates to:
  /// **'Деньги приняты, но фискальный чек аванса не выписан.'**
  String get prepaymentIntakeFiscalFailed;

  /// No description provided for @emulatorSettingsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Встроенные эмуляторы'**
  String get emulatorSettingsTitle;

  /// No description provided for @emulatorSettingsHint.
  ///
  /// In ru, this message translates to:
  /// **'Проверить печать и диагностику, не подключая приборов'**
  String get emulatorSettingsHint;

  /// No description provided for @emulatorReceiptPrinter.
  ///
  /// In ru, this message translates to:
  /// **'Чековый принтер и денежный ящик'**
  String get emulatorReceiptPrinter;

  /// No description provided for @emulatorEnabledNote.
  ///
  /// In ru, this message translates to:
  /// **'Сокет поднят. Касса попадёт на него только по адресу из привязки'**
  String get emulatorEnabledNote;

  /// No description provided for @emulatorDisabledNote.
  ///
  /// In ru, this message translates to:
  /// **'Выключен: сокет не открыт'**
  String get emulatorDisabledNote;

  /// No description provided for @emulatorAddress.
  ///
  /// In ru, this message translates to:
  /// **'Адрес эмулятора'**
  String get emulatorAddress;

  /// No description provided for @emulatorAddressHint.
  ///
  /// In ru, this message translates to:
  /// **'Впишите этот IP и порт в настройках принтера'**
  String get emulatorAddressHint;

  /// No description provided for @emulatorBindAction.
  ///
  /// In ru, this message translates to:
  /// **'Вписать в привязку принтера'**
  String get emulatorBindAction;

  /// No description provided for @emulatorBindDone.
  ///
  /// In ru, this message translates to:
  /// **'Привязка принтера теперь смотрит на эмулятор'**
  String get emulatorBindDone;

  /// No description provided for @emulatorBindingStale.
  ///
  /// In ru, this message translates to:
  /// **'Привязка принтера смотрит на выключенный эмулятор — печать откажет'**
  String get emulatorBindingStale;

  /// No description provided for @emulatorStartFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось поднять эмулятор'**
  String get emulatorStartFailed;

  /// No description provided for @emulatorFiscalOperator.
  ///
  /// In ru, this message translates to:
  /// **'Фискальный оператор (ОФД)'**
  String get emulatorFiscalOperator;

  /// No description provided for @emulatorFiscalAddressHint.
  ///
  /// In ru, this message translates to:
  /// **'Впишите этот адрес в поле «Адрес сервера» фискальных настроек'**
  String get emulatorFiscalAddressHint;

  /// No description provided for @emulatorFiscalBindAction.
  ///
  /// In ru, this message translates to:
  /// **'Вписать в фискальные настройки'**
  String get emulatorFiscalBindAction;

  /// No description provided for @emulatorFiscalBindNote.
  ///
  /// In ru, this message translates to:
  /// **'Впишет адрес, логин, пароль, ключ и заводской номер эмулятора и объявит кассу испытательной. Регистрационный номер не трогается'**
  String get emulatorFiscalBindNote;

  /// No description provided for @emulatorFiscalBindDone.
  ///
  /// In ru, this message translates to:
  /// **'Фискальные настройки теперь смотрят на эмулятор'**
  String get emulatorFiscalBindDone;

  /// No description provided for @emulatorFiscalBindingStale.
  ///
  /// In ru, this message translates to:
  /// **'Фискальные настройки смотрят на выключенный эмулятор — фискализация откажет'**
  String get emulatorFiscalBindingStale;

  /// No description provided for @emulatorFiscalLocalModuleWarning.
  ///
  /// In ru, this message translates to:
  /// **'Заполнено поле «Локальный модуль» — оно перебивает адрес сервера, и касса пойдёт не на эмулятор'**
  String get emulatorFiscalLocalModuleWarning;

  /// No description provided for @emulatorFiscalBlockedLive.
  ///
  /// In ru, this message translates to:
  /// **'Касса боевая: вписаны реквизиты оператора. Эмулятор ОФД здесь запрещён — чек, ушедший в подделку, выглядит настоящим, а документа покупателю не даёт'**
  String get emulatorFiscalBlockedLive;

  /// No description provided for @emulatorFiscalBlockedUnknown.
  ///
  /// In ru, this message translates to:
  /// **'Фискальные настройки не прочитались — включить эмулятор ОФД нельзя'**
  String get emulatorFiscalBlockedUnknown;

  /// No description provided for @diagnosticsFiscalEmulatorBanner.
  ///
  /// In ru, this message translates to:
  /// **'Адрес оператора ведёт на этот же компьютер — документы уходят в эмулятор и фискальными не являются'**
  String get diagnosticsFiscalEmulatorBanner;

  /// No description provided for @diagnosticsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Диагностика оборудования'**
  String get diagnosticsTitle;

  /// No description provided for @diagnosticsSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Что касса на самом деле отправила приборам'**
  String get diagnosticsSubtitle;

  /// No description provided for @diagnosticsTabPrinter.
  ///
  /// In ru, this message translates to:
  /// **'Принтер'**
  String get diagnosticsTabPrinter;

  /// No description provided for @diagnosticsTabFiscal.
  ///
  /// In ru, this message translates to:
  /// **'Фискализация'**
  String get diagnosticsTabFiscal;

  /// No description provided for @errorDiagnosticsUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Диагностику на этой кассе спросить не у кого'**
  String get errorDiagnosticsUnavailable;

  /// No description provided for @diagnosticsPrinterQueueMissing.
  ///
  /// In ru, this message translates to:
  /// **'Очередь печати на этом рабочем месте не настроена'**
  String get diagnosticsPrinterQueueMissing;

  /// No description provided for @diagnosticsPrinterNothingSent.
  ///
  /// In ru, this message translates to:
  /// **'Касса пока ничего не отправляла в принтер'**
  String get diagnosticsPrinterNothingSent;

  /// No description provided for @diagnosticsAskFailed.
  ///
  /// In ru, this message translates to:
  /// **'Касса не ответила на этот вопрос: {reason}'**
  String diagnosticsAskFailed(String reason);

  /// No description provided for @diagnosticsAttempts.
  ///
  /// In ru, this message translates to:
  /// **'попыток {count}'**
  String diagnosticsAttempts(int count);

  /// No description provided for @diagnosticsJobQueued.
  ///
  /// In ru, this message translates to:
  /// **'ждёт очереди'**
  String get diagnosticsJobQueued;

  /// No description provided for @diagnosticsJobPrinting.
  ///
  /// In ru, this message translates to:
  /// **'печатается'**
  String get diagnosticsJobPrinting;

  /// No description provided for @diagnosticsJobPrinted.
  ///
  /// In ru, this message translates to:
  /// **'напечатано'**
  String get diagnosticsJobPrinted;

  /// No description provided for @diagnosticsJobFailed.
  ///
  /// In ru, this message translates to:
  /// **'не напечатано'**
  String get diagnosticsJobFailed;

  /// No description provided for @diagnosticsJobExpired.
  ///
  /// In ru, this message translates to:
  /// **'просрочено'**
  String get diagnosticsJobExpired;

  /// No description provided for @diagnosticsJobCancelled.
  ///
  /// In ru, this message translates to:
  /// **'отменено'**
  String get diagnosticsJobCancelled;

  /// No description provided for @diagnosticsFiscalNotConfigured.
  ///
  /// In ru, this message translates to:
  /// **'Фискальный оператор на этой кассе не настроен'**
  String get diagnosticsFiscalNotConfigured;

  /// No description provided for @diagnosticsFiscalAccepted.
  ///
  /// In ru, this message translates to:
  /// **'Принято оператором'**
  String get diagnosticsFiscalAccepted;

  /// No description provided for @diagnosticsFiscalAcceptedEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Оператор пока не принял ни одного документа'**
  String get diagnosticsFiscalAcceptedEmpty;

  /// No description provided for @diagnosticsFiscalQueued.
  ///
  /// In ru, this message translates to:
  /// **'В очереди'**
  String get diagnosticsFiscalQueued;

  /// No description provided for @diagnosticsFiscalQueuedEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Очередь пуста — всё, что отправляли, оператор принял'**
  String get diagnosticsFiscalQueuedEmpty;

  /// No description provided for @diagnosticsFiscalSign.
  ///
  /// In ru, this message translates to:
  /// **'Фискальный признак {value}'**
  String diagnosticsFiscalSign(String value);

  /// No description provided for @diagnosticsFiscalOperatorDoc.
  ///
  /// In ru, this message translates to:
  /// **'документ оператора {value}'**
  String diagnosticsFiscalOperatorDoc(String value);

  /// No description provided for @diagnosticsFiscalReceiptNo.
  ///
  /// In ru, this message translates to:
  /// **'чек {value}'**
  String diagnosticsFiscalReceiptNo(String value);

  /// No description provided for @diagnosticsFiscalOffline.
  ///
  /// In ru, this message translates to:
  /// **'выдан автономно'**
  String get diagnosticsFiscalOffline;

  /// No description provided for @diagnosticsEmulatorBanner.
  ///
  /// In ru, this message translates to:
  /// **'Привязка принтера смотрит на этот же компьютер — за портом эмулятор, а не бумага'**
  String get diagnosticsEmulatorBanner;

  /// No description provided for @diagnosticsTabDrawer.
  ///
  /// In ru, this message translates to:
  /// **'Ящик'**
  String get diagnosticsTabDrawer;

  /// No description provided for @drawerDiagnosticsEmpty.
  ///
  /// In ru, this message translates to:
  /// **'С запуска кассы ящик не открывали ни разу'**
  String get drawerDiagnosticsEmpty;

  /// No description provided for @drawerDiagnosticsUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Памяти об импульсах ящика на этой кассе нет — спросить нечем. Это не значит, что ящик не открывали.'**
  String get drawerDiagnosticsUnavailable;

  /// No description provided for @drawerDiagnosticsCaveat.
  ///
  /// In ru, this message translates to:
  /// **'Касса знает только, приняли ли команду. Открылся ли ящик на самом деле, обратной связи нет ни на одном пути.'**
  String get drawerDiagnosticsCaveat;

  /// No description provided for @drawerDiagnosticsAccepted.
  ///
  /// In ru, this message translates to:
  /// **'Команда принята'**
  String get drawerDiagnosticsAccepted;

  /// No description provided for @drawerDiagnosticsRefused.
  ///
  /// In ru, this message translates to:
  /// **'Команда отклонена'**
  String get drawerDiagnosticsRefused;

  /// No description provided for @drawerDiagnosticsViaSerial.
  ///
  /// In ru, this message translates to:
  /// **'последовательный порт'**
  String get drawerDiagnosticsViaSerial;

  /// No description provided for @drawerDiagnosticsViaPrinter.
  ///
  /// In ru, this message translates to:
  /// **'через принтер (ESC p)'**
  String get drawerDiagnosticsViaPrinter;

  /// No description provided for @diagnosticsTabScales.
  ///
  /// In ru, this message translates to:
  /// **'Весы'**
  String get diagnosticsTabScales;

  /// No description provided for @diagnosticsTabDisplay.
  ///
  /// In ru, this message translates to:
  /// **'Дисплей'**
  String get diagnosticsTabDisplay;

  /// No description provided for @scalesDiagnosticsUnbound.
  ///
  /// In ru, this message translates to:
  /// **'Весы не привязаны к этой кассе.\nПривяжите их в настройках оборудования — тогда здесь появится показание.'**
  String get scalesDiagnosticsUnbound;

  /// No description provided for @scalesDiagnosticsWeight.
  ///
  /// In ru, this message translates to:
  /// **'Показание весов'**
  String get scalesDiagnosticsWeight;

  /// No description provided for @scalesDiagnosticsSilent.
  ///
  /// In ru, this message translates to:
  /// **'Весы ещё ничего не прислали'**
  String get scalesDiagnosticsSilent;

  /// No description provided for @scalesDiagnosticsStable.
  ///
  /// In ru, this message translates to:
  /// **'Вес устоялся'**
  String get scalesDiagnosticsStable;

  /// No description provided for @scalesDiagnosticsSettling.
  ///
  /// In ru, this message translates to:
  /// **'Вес меняется'**
  String get scalesDiagnosticsSettling;

  /// No description provided for @scalesDiagnosticsOverload.
  ///
  /// In ru, this message translates to:
  /// **'Перегрузка'**
  String get scalesDiagnosticsOverload;

  /// No description provided for @scalesDiagnosticsPort.
  ///
  /// In ru, this message translates to:
  /// **'Порт весов'**
  String get scalesDiagnosticsPort;

  /// No description provided for @scalesDiagnosticsBaudSuffix.
  ///
  /// In ru, this message translates to:
  /// **'бод'**
  String get scalesDiagnosticsBaudSuffix;

  /// No description provided for @scalesDiagnosticsConnected.
  ///
  /// In ru, this message translates to:
  /// **'Порт открыт'**
  String get scalesDiagnosticsConnected;

  /// No description provided for @scalesDiagnosticsDisconnected.
  ///
  /// In ru, this message translates to:
  /// **'Порт закрыт'**
  String get scalesDiagnosticsDisconnected;

  /// No description provided for @scalesDiagnosticsCaveat.
  ///
  /// In ru, this message translates to:
  /// **'Это то, что прислал прибор. Верность показаний касса не проверяет — за неё отвечает поверка.'**
  String get scalesDiagnosticsCaveat;

  /// No description provided for @displayDiagnosticsEmpty.
  ///
  /// In ru, this message translates to:
  /// **'С запуска кассы на дисплей ничего не отправляли'**
  String get displayDiagnosticsEmpty;

  /// No description provided for @displayDiagnosticsUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Памяти о строках дисплея на этой кассе нет — спросить нечем. Это не значит, что на дисплей ничего не отправляли.'**
  String get displayDiagnosticsUnavailable;

  /// No description provided for @displayDiagnosticsCurrent.
  ///
  /// In ru, this message translates to:
  /// **'Сейчас на дисплее'**
  String get displayDiagnosticsCurrent;

  /// No description provided for @displayDiagnosticsCaveat.
  ///
  /// In ru, this message translates to:
  /// **'Касса знает только, что строка ушла в порт. Погасший или отключённый дисплей отсюда неотличим от исправного.'**
  String get displayDiagnosticsCaveat;

  /// No description provided for @displayDiagnosticsCallPrice.
  ///
  /// In ru, this message translates to:
  /// **'цена'**
  String get displayDiagnosticsCallPrice;

  /// No description provided for @displayDiagnosticsCallTotal.
  ///
  /// In ru, this message translates to:
  /// **'итог'**
  String get displayDiagnosticsCallTotal;

  /// No description provided for @displayDiagnosticsCallChange.
  ///
  /// In ru, this message translates to:
  /// **'сдача'**
  String get displayDiagnosticsCallChange;

  /// No description provided for @displayDiagnosticsCallText.
  ///
  /// In ru, this message translates to:
  /// **'текст'**
  String get displayDiagnosticsCallText;

  /// No description provided for @displayDiagnosticsCallWelcome.
  ///
  /// In ru, this message translates to:
  /// **'приветствие'**
  String get displayDiagnosticsCallWelcome;

  /// No description provided for @displayDiagnosticsCallClear.
  ///
  /// In ru, this message translates to:
  /// **'очистка'**
  String get displayDiagnosticsCallClear;

  /// No description provided for @emulatorScaleWeight.
  ///
  /// In ru, this message translates to:
  /// **'Вес на чаше'**
  String get emulatorScaleWeight;

  /// No description provided for @emulatorScaleWeightHint.
  ///
  /// In ru, this message translates to:
  /// **'Пульт эмулятора: это число весы и пришлют кассе'**
  String get emulatorScaleWeightHint;

  /// No description provided for @emulatorQrProvider.
  ///
  /// In ru, this message translates to:
  /// **'Провайдер оплаты по QR'**
  String get emulatorQrProvider;

  /// No description provided for @emulatorQrAddressHint.
  ///
  /// In ru, this message translates to:
  /// **'Впишите этот адрес в настройке провайдера QR'**
  String get emulatorQrAddressHint;

  /// No description provided for @emulatorQrBindAction.
  ///
  /// In ru, this message translates to:
  /// **'Вписать в настройку QR'**
  String get emulatorQrBindAction;

  /// No description provided for @emulatorQrBindDone.
  ///
  /// In ru, this message translates to:
  /// **'Настройка QR теперь смотрит на эмулятор'**
  String get emulatorQrBindDone;

  /// No description provided for @emulatorQrBindingStale.
  ///
  /// In ru, this message translates to:
  /// **'Настройка QR смотрит на выключенный эмулятор — оплата по коду откажет'**
  String get emulatorQrBindingStale;

  /// No description provided for @diagnosticsTabPayment.
  ///
  /// In ru, this message translates to:
  /// **'Оплата'**
  String get diagnosticsTabPayment;

  /// No description provided for @diagnosticsPaymentEmulatorBanner.
  ///
  /// In ru, this message translates to:
  /// **'Провайдер QR — на этом же компьютере: за адресом эмулятор, а не банк'**
  String get diagnosticsPaymentEmulatorBanner;

  /// No description provided for @paymentDiagnosticsUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Данных об оплате на этом рабочем месте нет'**
  String get paymentDiagnosticsUnavailable;

  /// No description provided for @paymentDiagnosticsQrSection.
  ///
  /// In ru, this message translates to:
  /// **'Оплата по QR'**
  String get paymentDiagnosticsQrSection;

  /// No description provided for @paymentDiagnosticsQrEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Касса пока не заводила ни одного кода оплаты'**
  String get paymentDiagnosticsQrEmpty;

  /// No description provided for @paymentDiagnosticsQrNotConfigured.
  ///
  /// In ru, this message translates to:
  /// **'Провайдер QR на этой кассе не настроен'**
  String get paymentDiagnosticsQrNotConfigured;

  /// No description provided for @paymentDiagnosticsQrAddress.
  ///
  /// In ru, this message translates to:
  /// **'Провайдер: {address}'**
  String paymentDiagnosticsQrAddress(String address);

  /// No description provided for @paymentDiagnosticsQrUnknown.
  ///
  /// In ru, this message translates to:
  /// **'Тела запросов к провайдеру касса не хранит. Видно то, что осело в намерении: сумма, состояние, ид на той стороне и причина отказа.'**
  String get paymentDiagnosticsQrUnknown;

  /// No description provided for @paymentDiagnosticsTerminalSection.
  ///
  /// In ru, this message translates to:
  /// **'Терминал оплаты'**
  String get paymentDiagnosticsTerminalSection;

  /// No description provided for @paymentDiagnosticsTerminalEmpty.
  ///
  /// In ru, this message translates to:
  /// **'С запуска кассы в терминал оплаты не уходило ни одного кадра'**
  String get paymentDiagnosticsTerminalEmpty;

  /// No description provided for @paymentDiagnosticsTerminalUnknown.
  ///
  /// In ru, this message translates to:
  /// **'Журнал терминала живёт в памяти: обмены до перезапуска кассы не сохраняются, а операции, проведённые с самого терминала, касса не видит вовсе.'**
  String get paymentDiagnosticsTerminalUnknown;

  /// No description provided for @paymentDiagnosticsRequest.
  ///
  /// In ru, this message translates to:
  /// **'Запрос'**
  String get paymentDiagnosticsRequest;

  /// No description provided for @paymentDiagnosticsReply.
  ///
  /// In ru, this message translates to:
  /// **'Ответ'**
  String get paymentDiagnosticsReply;

  /// No description provided for @paymentDiagnosticsNoReply.
  ///
  /// In ru, this message translates to:
  /// **'Ответа не было'**
  String get paymentDiagnosticsNoReply;

  /// No description provided for @paymentDiagnosticsApproval.
  ///
  /// In ru, this message translates to:
  /// **'Код одобрения {value}'**
  String paymentDiagnosticsApproval(String value);

  /// No description provided for @paymentDiagnosticsTransaction.
  ///
  /// In ru, this message translates to:
  /// **'транзакция {value}'**
  String paymentDiagnosticsTransaction(String value);

  /// No description provided for @paymentDiagnosticsRefusal.
  ///
  /// In ru, this message translates to:
  /// **'Отказ: {value}'**
  String paymentDiagnosticsRefusal(String value);

  /// No description provided for @paymentDiagnosticsConfirmations.
  ///
  /// In ru, this message translates to:
  /// **'подтверждений {count}'**
  String paymentDiagnosticsConfirmations(int count);

  /// No description provided for @paymentDiagnosticsOrphanMoney.
  ///
  /// In ru, this message translates to:
  /// **'деньги без чека'**
  String get paymentDiagnosticsOrphanMoney;

  /// No description provided for @paymentDiagnosticsAfterGiveUp.
  ///
  /// In ru, this message translates to:
  /// **'подтверждено после того, как касса перестала ждать'**
  String get paymentDiagnosticsAfterGiveUp;

  /// No description provided for @paymentDiagnosticsApproved.
  ///
  /// In ru, this message translates to:
  /// **'Одобрено'**
  String get paymentDiagnosticsApproved;

  /// No description provided for @paymentDiagnosticsDeclined.
  ///
  /// In ru, this message translates to:
  /// **'Отказано'**
  String get paymentDiagnosticsDeclined;

  /// No description provided for @paymentDiagnosticsOpPurchase.
  ///
  /// In ru, this message translates to:
  /// **'покупка'**
  String get paymentDiagnosticsOpPurchase;

  /// No description provided for @paymentDiagnosticsOpReversal.
  ///
  /// In ru, this message translates to:
  /// **'сторно'**
  String get paymentDiagnosticsOpReversal;

  /// No description provided for @paymentDiagnosticsOpRefund.
  ///
  /// In ru, this message translates to:
  /// **'возврат'**
  String get paymentDiagnosticsOpRefund;

  /// No description provided for @paymentDiagnosticsOpUnknown.
  ///
  /// In ru, this message translates to:
  /// **'кадр неизвестного вида'**
  String get paymentDiagnosticsOpUnknown;

  /// No description provided for @certificateIssueTitle.
  ///
  /// In ru, this message translates to:
  /// **'Выпуск подарочного сертификата'**
  String get certificateIssueTitle;

  /// No description provided for @certificateIssueHint.
  ///
  /// In ru, this message translates to:
  /// **'Деньги за бумажку принимает чек продажи. Здесь бумажке заводится остаток, а касса берёт на себя обязательство.'**
  String get certificateIssueHint;

  /// No description provided for @certificateIssueNumber.
  ///
  /// In ru, this message translates to:
  /// **'Номер бумажки'**
  String get certificateIssueNumber;

  /// No description provided for @certificateIssueNominal.
  ///
  /// In ru, this message translates to:
  /// **'Номинал'**
  String get certificateIssueNominal;

  /// No description provided for @certificateIssuePin.
  ///
  /// In ru, this message translates to:
  /// **'ПИН (необязательно)'**
  String get certificateIssuePin;

  /// No description provided for @certificateIssueExpiresDays.
  ///
  /// In ru, this message translates to:
  /// **'Срок годности в днях (необязательно)'**
  String get certificateIssueExpiresDays;

  /// No description provided for @certificateIssueReceipt.
  ///
  /// In ru, this message translates to:
  /// **'Номер чека продажи (необязательно)'**
  String get certificateIssueReceipt;

  /// No description provided for @certificateIssueSubmit.
  ///
  /// In ru, this message translates to:
  /// **'Выпустить сертификат'**
  String get certificateIssueSubmit;

  /// No description provided for @certificateIssueDone.
  ///
  /// In ru, this message translates to:
  /// **'Сертификат {number} выпущен на {amount}'**
  String certificateIssueDone(String number, String amount);

  /// No description provided for @certificateIssueFailed.
  ///
  /// In ru, this message translates to:
  /// **'Сертификат не выпущен'**
  String get certificateIssueFailed;

  /// No description provided for @certificateIssueNumberRequired.
  ///
  /// In ru, this message translates to:
  /// **'Впишите номер бумажки'**
  String get certificateIssueNumberRequired;

  /// No description provided for @certificateIssueNominalInvalid.
  ///
  /// In ru, this message translates to:
  /// **'Номинал должен быть больше нуля'**
  String get certificateIssueNominalInvalid;

  /// Отказ показывается на месте нажатия, а не прячет кнопку: спрятанная кнопка правом не является (I162).
  ///
  /// In ru, this message translates to:
  /// **'Выпуск сертификатов этому кассиру не разрешён'**
  String get certificateIssueNotPermitted;

  /// No description provided for @certificateSlipTitle.
  ///
  /// In ru, this message translates to:
  /// **'Напечатать слип заново'**
  String get certificateSlipTitle;

  /// No description provided for @certificateSlipHint.
  ///
  /// In ru, this message translates to:
  /// **'Слип не напечатался при выпуске — бумажку можно выдать по повторному.'**
  String get certificateSlipHint;

  /// No description provided for @certificateSlipNumber.
  ///
  /// In ru, this message translates to:
  /// **'Номер сертификата'**
  String get certificateSlipNumber;

  /// No description provided for @certificateSlipPin.
  ///
  /// In ru, this message translates to:
  /// **'ПИН, если он есть'**
  String get certificateSlipPin;

  /// No description provided for @certificateSlipSubmit.
  ///
  /// In ru, this message translates to:
  /// **'Напечатать слип'**
  String get certificateSlipSubmit;

  /// No description provided for @certificateSlipDone.
  ///
  /// In ru, this message translates to:
  /// **'Слип сертификата {number} отправлен в печать'**
  String certificateSlipDone(String number);

  /// No description provided for @certificateSlipFailed.
  ///
  /// In ru, this message translates to:
  /// **'Слип в печать не отправлен'**
  String get certificateSlipFailed;

  /// No description provided for @certificateSlipUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'На этой кассе слип печатать нечем'**
  String get certificateSlipUnavailable;

  /// No description provided for @prepaymentRefundTitle.
  ///
  /// In ru, this message translates to:
  /// **'Выдача аванса'**
  String get prepaymentRefundTitle;

  /// No description provided for @prepaymentRefundHint.
  ///
  /// In ru, this message translates to:
  /// **'Возвращаются деньги, внесённые покупателем вперёд. Долг этим не гасится, бонусы не трогаются.'**
  String get prepaymentRefundHint;

  /// No description provided for @prepaymentRefundBalance.
  ///
  /// In ru, this message translates to:
  /// **'Внесено вперёд: {amount}'**
  String prepaymentRefundBalance(String amount);

  /// No description provided for @prepaymentRefundNothing.
  ///
  /// In ru, this message translates to:
  /// **'Аванса на счёте покупателя нет — выдавать нечего'**
  String get prepaymentRefundNothing;

  /// No description provided for @prepaymentRefundAmount.
  ///
  /// In ru, this message translates to:
  /// **'Сумма к выдаче'**
  String get prepaymentRefundAmount;

  /// No description provided for @prepaymentRefundTender.
  ///
  /// In ru, this message translates to:
  /// **'Чем выдать'**
  String get prepaymentRefundTender;

  /// No description provided for @prepaymentRefundIntake.
  ///
  /// In ru, this message translates to:
  /// **'Номер проводки приёма (необязательно)'**
  String get prepaymentRefundIntake;

  /// No description provided for @prepaymentRefundSubmit.
  ///
  /// In ru, this message translates to:
  /// **'Выдать аванс'**
  String get prepaymentRefundSubmit;

  /// No description provided for @prepaymentRefundDone.
  ///
  /// In ru, this message translates to:
  /// **'Аванс выдан. Осталось на счёте: {amount}'**
  String prepaymentRefundDone(String amount);

  /// No description provided for @prepaymentRefundFailed.
  ///
  /// In ru, this message translates to:
  /// **'Аванс не выдан'**
  String get prepaymentRefundFailed;

  /// No description provided for @prepaymentRefundAmountInvalid.
  ///
  /// In ru, this message translates to:
  /// **'Сумма должна быть больше нуля'**
  String get prepaymentRefundAmountInvalid;

  /// No description provided for @prepaymentRefundNotPermitted.
  ///
  /// In ru, this message translates to:
  /// **'Выдача аванса этому кассиру не разрешена'**
  String get prepaymentRefundNotPermitted;

  /// No description provided for @prepaymentRefundFiscalFailed.
  ///
  /// In ru, this message translates to:
  /// **'Деньги выданы, но фискальный чек возврата аванса не выписан.'**
  String get prepaymentRefundFiscalFailed;

  /// No description provided for @agentRefundPrepayment.
  ///
  /// In ru, this message translates to:
  /// **'Выдать аванс'**
  String get agentRefundPrepayment;

  /// No description provided for @repTitle.
  ///
  /// In ru, this message translates to:
  /// **'Отчеты'**
  String get repTitle;

  /// No description provided for @repTabAnalytics.
  ///
  /// In ru, this message translates to:
  /// **'Аналитика'**
  String get repTabAnalytics;

  /// No description provided for @repTabFinance.
  ///
  /// In ru, this message translates to:
  /// **'Финансы'**
  String get repTabFinance;

  /// No description provided for @repTabForecasts.
  ///
  /// In ru, this message translates to:
  /// **'Прогнозы'**
  String get repTabForecasts;

  /// No description provided for @repTabTaxKz.
  ///
  /// In ru, this message translates to:
  /// **'Налоги/КЗ'**
  String get repTabTaxKz;

  /// No description provided for @repRangeDays7.
  ///
  /// In ru, this message translates to:
  /// **'7 дней'**
  String get repRangeDays7;

  /// No description provided for @repRangeDays30.
  ///
  /// In ru, this message translates to:
  /// **'30 дней'**
  String get repRangeDays30;

  /// No description provided for @repRangeCustom.
  ///
  /// In ru, this message translates to:
  /// **'Произвольно'**
  String get repRangeCustom;

  /// No description provided for @repKpiChange.
  ///
  /// In ru, this message translates to:
  /// **'Изменение'**
  String get repKpiChange;

  /// No description provided for @repSubtitleVsPrev.
  ///
  /// In ru, this message translates to:
  /// **'vs пред. период'**
  String get repSubtitleVsPrev;

  /// No description provided for @repChartRevenueByDay.
  ///
  /// In ru, this message translates to:
  /// **'Выручка по дням'**
  String get repChartRevenueByDay;

  /// No description provided for @repChartTop5Products.
  ///
  /// In ru, this message translates to:
  /// **'Топ-5 товаров'**
  String get repChartTop5Products;

  /// No description provided for @repChartPaymentMethods.
  ///
  /// In ru, this message translates to:
  /// **'Способы оплаты'**
  String get repChartPaymentMethods;

  /// No description provided for @settingsRestartRequired.
  ///
  /// In ru, this message translates to:
  /// **'Изменения применяются при следующем запуске кассы.'**
  String get settingsRestartRequired;

  /// No description provided for @hardwareRestartRequired.
  ///
  /// In ru, this message translates to:
  /// **'Изменения устройств применяются при следующем запуске кассы.'**
  String get hardwareRestartRequired;

  /// No description provided for @hardwareDeviceDisabled.
  ///
  /// In ru, this message translates to:
  /// **'Устройство отключено.'**
  String get hardwareDeviceDisabled;

  /// No description provided for @hardwareCustomerDisplayGraphic.
  ///
  /// In ru, this message translates to:
  /// **'Графический экран покупателя (2-й монитор)'**
  String get hardwareCustomerDisplayGraphic;

  /// No description provided for @hardwareCustomerDisplayGraphicOff.
  ///
  /// In ru, this message translates to:
  /// **'Графический экран покупателя отключён.'**
  String get hardwareCustomerDisplayGraphicOff;

  /// No description provided for @hardwarePaymentKinds.
  ///
  /// In ru, this message translates to:
  /// **'Виды оплаты рабочего места'**
  String get hardwarePaymentKinds;

  /// No description provided for @hardwarePaymentKindsUnrestricted.
  ///
  /// In ru, this message translates to:
  /// **'Ограничений нет: рабочее место принимает все виды оплаты.'**
  String get hardwarePaymentKindsUnrestricted;

  /// No description provided for @fiscalSettingsDirectOfdLabel.
  ///
  /// In ru, this message translates to:
  /// **'Прямое подключение ОФД'**
  String get fiscalSettingsDirectOfdLabel;

  /// No description provided for @markupAuto.
  ///
  /// In ru, this message translates to:
  /// **'Авто-наценка'**
  String get markupAuto;

  /// No description provided for @markupSave.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить наценки'**
  String get markupSave;

  /// No description provided for @creditContractNumberLabel.
  ///
  /// In ru, this message translates to:
  /// **'Номер договора с бумажки'**
  String get creditContractNumberLabel;

  /// No description provided for @creditNoLiveContracts.
  ///
  /// In ru, this message translates to:
  /// **'Живых договоров рассрочки нет'**
  String get creditNoLiveContracts;

  /// No description provided for @supplierOrderTitle.
  ///
  /// In ru, this message translates to:
  /// **'Заявка поставщику'**
  String get supplierOrderTitle;

  /// No description provided for @supplierOrderAllStocked.
  ///
  /// In ru, this message translates to:
  /// **'Все товары в достаточном количестве'**
  String get supplierOrderAllStocked;

  /// No description provided for @supplierOrderNotNeeded.
  ///
  /// In ru, this message translates to:
  /// **'Дозаказ не требуется'**
  String get supplierOrderNotNeeded;

  /// No description provided for @hwScaleTitle.
  ///
  /// In ru, this message translates to:
  /// **'Весы'**
  String get hwScaleTitle;

  /// No description provided for @hwReceiptPrinterTitle.
  ///
  /// In ru, this message translates to:
  /// **'Чековый принтер'**
  String get hwReceiptPrinterTitle;

  /// No description provided for @repRangeDays14.
  ///
  /// In ru, this message translates to:
  /// **'14 дней'**
  String get repRangeDays14;

  /// No description provided for @repForecastSmaLowData.
  ///
  /// In ru, this message translates to:
  /// **'SMA (мало данных)'**
  String get repForecastSmaLowData;

  /// No description provided for @repNoCategory.
  ///
  /// In ru, this message translates to:
  /// **'Без категории'**
  String get repNoCategory;

  /// No description provided for @repAllCustomers.
  ///
  /// In ru, this message translates to:
  /// **'Все клиенты'**
  String get repAllCustomers;

  /// No description provided for @repAllInStock.
  ///
  /// In ru, this message translates to:
  /// **'Все товары в наличии'**
  String get repAllInStock;

  /// No description provided for @repAllCovered30.
  ///
  /// In ru, this message translates to:
  /// **'Все товары обеспечены на 30+ дней'**
  String get repAllCovered30;

  /// No description provided for @repColDays.
  ///
  /// In ru, this message translates to:
  /// **'Дней'**
  String get repColDays;

  /// No description provided for @repColDaysLeft.
  ///
  /// In ru, this message translates to:
  /// **'Дней до конца'**
  String get repColDaysLeft;

  /// No description provided for @repColSharePct.
  ///
  /// In ru, this message translates to:
  /// **'Доля %'**
  String get repColSharePct;

  /// No description provided for @repColChangePct.
  ///
  /// In ru, this message translates to:
  /// **'Изменение %'**
  String get repColChangePct;

  /// No description provided for @repColSalesCount.
  ///
  /// In ru, this message translates to:
  /// **'Кол-во продаж'**
  String get repColSalesCount;

  /// No description provided for @repReceiptCountLabel.
  ///
  /// In ru, this message translates to:
  /// **'Количество чеков'**
  String get repReceiptCountLabel;

  /// No description provided for @repStockCritical.
  ///
  /// In ru, this message translates to:
  /// **'Критически низкий остаток! Требуется срочная поставка.'**
  String get repStockCritical;

  /// No description provided for @repColCumulativePct.
  ///
  /// In ru, this message translates to:
  /// **'Накопит. %'**
  String get repColCumulativePct;

  /// No description provided for @repNotEnoughSalesData.
  ///
  /// In ru, this message translates to:
  /// **'Недостаточно данных о продажах за выбранный период'**
  String get repNotEnoughSalesData;

  /// No description provided for @repNoForecastData.
  ///
  /// In ru, this message translates to:
  /// **'Нет данных для прогноза'**
  String get repNoForecastData;

  /// No description provided for @repNoDataLast90.
  ///
  /// In ru, this message translates to:
  /// **'Нет данных за последние 90 дней'**
  String get repNoDataLast90;

  /// No description provided for @repNoCustomerData.
  ///
  /// In ru, this message translates to:
  /// **'Нет данных о клиентах'**
  String get repNoCustomerData;

  /// No description provided for @repNoLowStock.
  ///
  /// In ru, this message translates to:
  /// **'Нет товаров с низким остатком'**
  String get repNoLowStock;

  /// No description provided for @repLowStock.
  ///
  /// In ru, this message translates to:
  /// **'Низкий остаток'**
  String get repLowStock;

  /// No description provided for @repNewPrice.
  ///
  /// In ru, this message translates to:
  /// **'Новая цена'**
  String get repNewPrice;

  /// No description provided for @repColEstimatedAmount.
  ///
  /// In ru, this message translates to:
  /// **'Ориент. сумма'**
  String get repColEstimatedAmount;

  /// No description provided for @repColSeatings.
  ///
  /// In ru, this message translates to:
  /// **'Посадок'**
  String get repColSeatings;

  /// No description provided for @repForecast.
  ///
  /// In ru, this message translates to:
  /// **'Прогноз'**
  String get repForecast;

  /// No description provided for @repRevenueForecast.
  ///
  /// In ru, this message translates to:
  /// **'Прогноз выручки'**
  String get repRevenueForecast;

  /// No description provided for @repRevenueForecastHw.
  ///
  /// In ru, this message translates to:
  /// **'Прогноз выручки (Holt-Winters)'**
  String get repRevenueForecastHw;

  /// No description provided for @repStockoutForecast.
  ///
  /// In ru, this message translates to:
  /// **'Прогноз исчерпания остатков'**
  String get repStockoutForecast;

  /// No description provided for @repStockForecast.
  ///
  /// In ru, this message translates to:
  /// **'Прогноз остатков'**
  String get repStockForecast;

  /// No description provided for @repSalesWithoutCustomerHidden.
  ///
  /// In ru, this message translates to:
  /// **'Продажи без привязки к клиенту не отображаются'**
  String get repSalesWithoutCustomerHidden;

  /// No description provided for @repColSalesPerDay.
  ///
  /// In ru, this message translates to:
  /// **'Продажи/день'**
  String get repColSalesPerDay;

  /// No description provided for @repColSold.
  ///
  /// In ru, this message translates to:
  /// **'Продано'**
  String get repColSold;

  /// No description provided for @repHourlyDistribution.
  ///
  /// In ru, this message translates to:
  /// **'Распределение по часам'**
  String get repHourlyDistribution;

  /// No description provided for @repColRecommendedOrder.
  ///
  /// In ru, this message translates to:
  /// **'Рек. заказ'**
  String get repColRecommendedOrder;

  /// No description provided for @repRecommendedPurchases.
  ///
  /// In ru, this message translates to:
  /// **'Рекомендуемые закупки'**
  String get repRecommendedPurchases;

  /// No description provided for @repColAvgSalesPerDay.
  ///
  /// In ru, this message translates to:
  /// **'Ср. продажи/день'**
  String get repColAvgSalesPerDay;

  /// No description provided for @repColAvgCheckShort.
  ///
  /// In ru, this message translates to:
  /// **'Ср. чек'**
  String get repColAvgCheckShort;

  /// No description provided for @repAvgPrice.
  ///
  /// In ru, this message translates to:
  /// **'Средняя цена'**
  String get repAvgPrice;

  /// No description provided for @repOldPrice.
  ///
  /// In ru, this message translates to:
  /// **'Старая цена'**
  String get repOldPrice;

  /// No description provided for @repStockValue.
  ///
  /// In ru, this message translates to:
  /// **'Стоимость остатка'**
  String get repStockValue;

  /// No description provided for @repColTable.
  ///
  /// In ru, this message translates to:
  /// **'Стол'**
  String get repColTable;

  /// No description provided for @repCurrentStock.
  ///
  /// In ru, this message translates to:
  /// **'Текущий остаток'**
  String get repCurrentStock;

  /// No description provided for @repTop10Customers.
  ///
  /// In ru, this message translates to:
  /// **'Топ-10 клиентов'**
  String get repTop10Customers;

  /// No description provided for @repTop10Products.
  ///
  /// In ru, this message translates to:
  /// **'Топ-10 товаров'**
  String get repTop10Products;

  /// No description provided for @repActual.
  ///
  /// In ru, this message translates to:
  /// **'Факт'**
  String get repActual;

  /// No description provided for @repColHour.
  ///
  /// In ru, this message translates to:
  /// **'Час'**
  String get repColHour;

  /// No description provided for @repExport.
  ///
  /// In ru, this message translates to:
  /// **'Экспорт'**
  String get repExport;

  /// No description provided for @repCashierPerformance.
  ///
  /// In ru, this message translates to:
  /// **'Эффективность кассиров'**
  String get repCashierPerformance;

  /// No description provided for @repWeightedAvgHint.
  ///
  /// In ru, this message translates to:
  /// **'взвешенное среднее (последние дни имеют больший вес)'**
  String get repWeightedAvgHint;

  /// No description provided for @repSalesCountByHour.
  ///
  /// In ru, this message translates to:
  /// **'количество продаж по часам'**
  String get repSalesCountByHour;

  /// No description provided for @repNoUrgentItems.
  ///
  /// In ru, this message translates to:
  /// **'нет срочных позиций'**
  String get repNoUrgentItems;

  /// No description provided for @repByRevenueTapHint.
  ///
  /// In ru, this message translates to:
  /// **'по выручке (нажмите для деталей)'**
  String get repByRevenueTapHint;

  /// No description provided for @repDistributionTapHint.
  ///
  /// In ru, this message translates to:
  /// **'распределение (нажмите на сектор)'**
  String get repDistributionTapHint;

  /// No description provided for @repRevenueDistributionTapHint.
  ///
  /// In ru, this message translates to:
  /// **'распределение выручки (нажмите на сектор)'**
  String get repRevenueDistributionTapHint;

  /// No description provided for @repAbcRare.
  ///
  /// In ru, this message translates to:
  /// **'редкие'**
  String get repAbcRare;

  /// No description provided for @repAbcMedium.
  ///
  /// In ru, this message translates to:
  /// **'средние'**
  String get repAbcMedium;

  /// No description provided for @repAbcFast.
  ///
  /// In ru, this message translates to:
  /// **'ходовые'**
  String get repAbcFast;

  /// No description provided for @repAbcLegend.
  ///
  /// In ru, this message translates to:
  /// **'ходовые (A), средние (B), редкие (C) — по вкладу в выручку'**
  String get repAbcLegend;

  /// No description provided for @repReturnsCount.
  ///
  /// In ru, this message translates to:
  /// **'{count} возвратов'**
  String repReturnsCount(int count);

  /// No description provided for @repAbcGroupSummary.
  ///
  /// In ru, this message translates to:
  /// **'{count} тов · {pct}%'**
  String repAbcGroupSummary(int count, String pct);

  /// No description provided for @repCustomerTooltip.
  ///
  /// In ru, this message translates to:
  /// **'{name}\n{amount} ({count} чеков)'**
  String repCustomerTooltip(String name, String amount, int count);

  /// No description provided for @repDaysCountTapHint.
  ///
  /// In ru, this message translates to:
  /// **'{count} дней (нажмите для деталей)'**
  String repDaysCountTapHint(int count);

  /// No description provided for @repCashiersCount.
  ///
  /// In ru, this message translates to:
  /// **'{count} кассиров'**
  String repCashiersCount(int count);

  /// No description provided for @repLowStockCountHint.
  ///
  /// In ru, this message translates to:
  /// **'{count} товаров (остаток < 10, нажмите для деталей)'**
  String repLowStockCountHint(int count);

  /// No description provided for @repOrdersShort.
  ///
  /// In ru, this message translates to:
  /// **'{count} зак.'**
  String repOrdersShort(int count);

  /// No description provided for @repOrdersRevenueTooltip.
  ///
  /// In ru, this message translates to:
  /// **'{count} зак.\n{amount}'**
  String repOrdersRevenueTooltip(int count, String amount);

  /// No description provided for @repPieces.
  ///
  /// In ru, this message translates to:
  /// **'{qty} шт'**
  String repPieces(String qty);

  /// No description provided for @repPiecesDot.
  ///
  /// In ru, this message translates to:
  /// **'{qty} шт.'**
  String repPiecesDot(String qty);

  /// No description provided for @repForecastSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'{actual} дней факт + {horizon} дней прогноз ({algorithm})'**
  String repForecastSubtitle(int actual, int horizon, String algorithm);

  /// No description provided for @repSalesCountLine.
  ///
  /// In ru, this message translates to:
  /// **'{count} продаж'**
  String repSalesCountLine(int count);

  /// No description provided for @repReceiptsCount.
  ///
  /// In ru, this message translates to:
  /// **'{count} чеков'**
  String repReceiptsCount(int count);

  /// No description provided for @repSupplierTooltip.
  ///
  /// In ru, this message translates to:
  /// **'{name}\n{count} поставок'**
  String repSupplierTooltip(String name, int count);

  /// No description provided for @repSeatingsLine.
  ///
  /// In ru, this message translates to:
  /// **'{count} посадок'**
  String repSeatingsLine(int count);

  /// No description provided for @repDayOffset.
  ///
  /// In ru, this message translates to:
  /// **'+{n} день'**
  String repDayOffset(int n);

  /// No description provided for @repHoltWintersSeason.
  ///
  /// In ru, this message translates to:
  /// **'Holt-Winters (сезон={season})'**
  String repHoltWintersSeason(int season);

  /// No description provided for @repInvestmentsLine.
  ///
  /// In ru, this message translates to:
  /// **'Вложения: {amount}'**
  String repInvestmentsLine(String amount);

  /// No description provided for @repDividendsLine.
  ///
  /// In ru, this message translates to:
  /// **'Дивиденды: {amount}'**
  String repDividendsLine(String amount);

  /// No description provided for @repMarginLine.
  ///
  /// In ru, this message translates to:
  /// **'Маржа: {pct}%'**
  String repMarginLine(String pct);

  /// No description provided for @repKpiLoadErrorWith.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка загрузки KPI: {error}'**
  String repKpiLoadErrorWith(String error);

  /// No description provided for @repErrorWith.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка: {error}'**
  String repErrorWith(String error);

  /// No description provided for @repProfitLine.
  ///
  /// In ru, this message translates to:
  /// **'Прибыль: {amount}'**
  String repProfitLine(String amount);

  /// No description provided for @repExpensesLine.
  ///
  /// In ru, this message translates to:
  /// **'Расходы: {amount}'**
  String repExpensesLine(String amount);

  /// No description provided for @repLeadTimeHint.
  ///
  /// In ru, this message translates to:
  /// **'срок поставки {lead} дн. + страховой запас {safety} дн.'**
  String repLeadTimeHint(int lead, int safety);

  /// No description provided for @markupHint.
  ///
  /// In ru, this message translates to:
  /// **'Наценка в % на категорию. При приходе товара розничная цена пересчитывается из закупочной: закуп × (1 + наценка%).'**
  String get markupHint;

  /// No description provided for @creditContractsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Рассрочки'**
  String get creditContractsTitle;

  /// No description provided for @creditContractsTitleFor.
  ///
  /// In ru, this message translates to:
  /// **'Рассрочки — {agent}'**
  String creditContractsTitleFor(String agent);

  /// No description provided for @repExportedTo.
  ///
  /// In ru, this message translates to:
  /// **'Экспортировано: {path}'**
  String repExportedTo(String path);

  /// No description provided for @repExportFailed.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка экспорта: {error}'**
  String repExportFailed(String error);

  /// No description provided for @hwSetupIncompleteDevices.
  ///
  /// In ru, this message translates to:
  /// **'Мастер настройки ещё не завершён — устройства сохранить некуда'**
  String get hwSetupIncompleteDevices;

  /// No description provided for @hwSetupIncompleteCheck.
  ///
  /// In ru, this message translates to:
  /// **'Мастер настройки ещё не завершён — проверять пока нечего'**
  String get hwSetupIncompleteCheck;

  /// No description provided for @settingsSetupIncompleteSave.
  ///
  /// In ru, this message translates to:
  /// **'Мастер настройки ещё не завершён — сохранить некуда'**
  String get settingsSetupIncompleteSave;

  /// No description provided for @hwProfileCatalogUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Каталог профилей устройств недоступен — настройки устройств сейчас нельзя изменить.'**
  String get hwProfileCatalogUnavailable;

  /// No description provided for @printerProfileCatalogUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Каталог профилей устройств недоступен — настройки принтера сейчас нельзя изменить.'**
  String get printerProfileCatalogUnavailable;

  /// No description provided for @labelPrinterProfileCatalogUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Каталог профилей устройств недоступен — настройки принтера этикеток сейчас нельзя изменить.'**
  String get labelPrinterProfileCatalogUnavailable;

  /// No description provided for @hwPaymentKindsUnsupported.
  ///
  /// In ru, this message translates to:
  /// **'Эта сборка не умеет сохранять виды оплаты рабочего места.'**
  String get hwPaymentKindsUnsupported;

  /// No description provided for @hwPaymentKindsEnforcedByTill.
  ///
  /// In ru, this message translates to:
  /// **'Запрет проверяет касса: терминал, которому вид оплаты не разрешён, получит отказ, даже если кнопка на его экране осталась.'**
  String get hwPaymentKindsEnforcedByTill;

  /// No description provided for @hwCustomerDisplayGraphicDesc.
  ///
  /// In ru, this message translates to:
  /// **'Красивый графический экран для клиента на втором мониторе: позиции чека, количество и итог в реальном времени.'**
  String get hwCustomerDisplayGraphicDesc;

  /// No description provided for @hwCustomerDisplayMonitor.
  ///
  /// In ru, this message translates to:
  /// **'Монитор для экрана покупателя'**
  String get hwCustomerDisplayMonitor;

  /// No description provided for @hwCustomerDisplayMonitorHint.
  ///
  /// In ru, this message translates to:
  /// **'POS остаётся на основном мониторе. Открывается автоматически при следующем запуске кассы.'**
  String get hwCustomerDisplayMonitorHint;

  /// No description provided for @hwNoProfilesForClass.
  ///
  /// In ru, this message translates to:
  /// **'Нет доступных моделей для этого класса устройств.'**
  String get hwNoProfilesForClass;

  /// No description provided for @hwNoConnectionParams.
  ///
  /// In ru, this message translates to:
  /// **'Эта модель не требует дополнительных параметров подключения.'**
  String get hwNoConnectionParams;

  /// No description provided for @hwMonitorWithSize.
  ///
  /// In ru, this message translates to:
  /// **'Монитор {index} — {size}'**
  String hwMonitorWithSize(int index, String size);

  /// No description provided for @hwMonitorNumbered.
  ///
  /// In ru, this message translates to:
  /// **'Монитор {index}'**
  String hwMonitorNumbered(int index);

  /// No description provided for @hwPaymentKindsError.
  ///
  /// In ru, this message translates to:
  /// **'Виды оплаты: {error}'**
  String hwPaymentKindsError(String error);

  /// No description provided for @hwPaymentKindsUnknown.
  ///
  /// In ru, this message translates to:
  /// **'В настройке этого рабочего места записаны виды, которых эта версия не знает: {list}. Ограничение по ним не действует. Выберите виды заново, чтобы починить запись — пока вы этого не сделали, она остаётся как есть.'**
  String hwPaymentKindsUnknown(String list);

  /// No description provided for @hwParamOptional.
  ///
  /// In ru, this message translates to:
  /// **'{description} (необязательно)'**
  String hwParamOptional(String description);

  /// No description provided for @globalMillimetres.
  ///
  /// In ru, this message translates to:
  /// **'{value} мм'**
  String globalMillimetres(String value);

  /// No description provided for @devProfilePrinterEscpos80mm.
  ///
  /// In ru, this message translates to:
  /// **'Чековый принтер ESC/POS 80 мм'**
  String get devProfilePrinterEscpos80mm;

  /// No description provided for @devProfilePrinterEscpos58mm.
  ///
  /// In ru, this message translates to:
  /// **'Чековый принтер ESC/POS 58 мм (компактный, без ножа)'**
  String get devProfilePrinterEscpos58mm;

  /// No description provided for @devProfilePrinterEscposUsb.
  ///
  /// In ru, this message translates to:
  /// **'Чековый принтер ESC/POS, USB/спулер'**
  String get devProfilePrinterEscposUsb;

  /// No description provided for @devProfilePrinterEscposBluetooth.
  ///
  /// In ru, this message translates to:
  /// **'Чековый принтер ESC/POS, Bluetooth'**
  String get devProfilePrinterEscposBluetooth;

  /// No description provided for @devProfilePrinterEscposSerial.
  ///
  /// In ru, this message translates to:
  /// **'Чековый принтер ESC/POS, последовательный порт'**
  String get devProfilePrinterEscposSerial;

  /// No description provided for @devProfilePrinterLabelZpl104.
  ///
  /// In ru, this message translates to:
  /// **'Принтер этикеток ZPL 104 мм'**
  String get devProfilePrinterLabelZpl104;

  /// No description provided for @devProfilePrinterLabelEpl58.
  ///
  /// In ru, this message translates to:
  /// **'Принтер этикеток EPL 58 мм'**
  String get devProfilePrinterLabelEpl58;

  /// No description provided for @devProfileScannerUsbHid.
  ///
  /// In ru, this message translates to:
  /// **'USB-сканер штрихкода (HID)'**
  String get devProfileScannerUsbHid;

  /// No description provided for @devProfileScannerBluetoothHid.
  ///
  /// In ru, this message translates to:
  /// **'Bluetooth-сканер штрихкода (HID)'**
  String get devProfileScannerBluetoothHid;

  /// No description provided for @devProfileScannerCamera.
  ///
  /// In ru, this message translates to:
  /// **'Сканер по камере устройства'**
  String get devProfileScannerCamera;

  /// No description provided for @devProfileScannerSerial.
  ///
  /// In ru, this message translates to:
  /// **'Сканер штрихкода, последовательный порт'**
  String get devProfileScannerSerial;

  /// No description provided for @devProfileScaleCasPd2.
  ///
  /// In ru, this message translates to:
  /// **'Весы CAS PD-II (последовательные)'**
  String get devProfileScaleCasPd2;

  /// No description provided for @devProfileScaleCasErPlus.
  ///
  /// In ru, this message translates to:
  /// **'Весы CAS ER-Plus'**
  String get devProfileScaleCasErPlus;

  /// No description provided for @devProfileDrawerViaPrinter.
  ///
  /// In ru, this message translates to:
  /// **'Денежный ящик через принтер (RJ11)'**
  String get devProfileDrawerViaPrinter;

  /// No description provided for @devProfileDrawerStandalone.
  ///
  /// In ru, this message translates to:
  /// **'Автономный денежный ящик (RJ11)'**
  String get devProfileDrawerStandalone;

  /// No description provided for @devProfileDisplayVfd.
  ///
  /// In ru, this message translates to:
  /// **'Дисплей покупателя VFD (последовательный)'**
  String get devProfileDisplayVfd;

  /// No description provided for @devProfileDisplayLcd2x20.
  ///
  /// In ru, this message translates to:
  /// **'Дисплей покупателя LCD 2x20'**
  String get devProfileDisplayLcd2x20;

  /// No description provided for @devProfileDisplayLed8.
  ///
  /// In ru, this message translates to:
  /// **'Дисплей покупателя LED (8 символов)'**
  String get devProfileDisplayLed8;

  /// No description provided for @devProfilePaymentKaspiPos.
  ///
  /// In ru, this message translates to:
  /// **'Терминал Kaspi POS'**
  String get devProfilePaymentKaspiPos;

  /// No description provided for @devParamPrinterIpAddress.
  ///
  /// In ru, this message translates to:
  /// **'IP-адрес сетевого принтера'**
  String get devParamPrinterIpAddress;

  /// No description provided for @devParamTcpPort9100.
  ///
  /// In ru, this message translates to:
  /// **'TCP-порт, по умолчанию 9100'**
  String get devParamTcpPort9100;

  /// No description provided for @devParamPrinterDevicePath.
  ///
  /// In ru, this message translates to:
  /// **'Путь к устройству или имя очереди печати'**
  String get devParamPrinterDevicePath;

  /// No description provided for @devParamPrinterMac.
  ///
  /// In ru, this message translates to:
  /// **'MAC-адрес сопряжённого Bluetooth-принтера'**
  String get devParamPrinterMac;

  /// No description provided for @devParamPrinterComPort.
  ///
  /// In ru, this message translates to:
  /// **'Последовательный порт принтера, например COM4'**
  String get devParamPrinterComPort;

  /// No description provided for @devParamLabelPrinterIp.
  ///
  /// In ru, this message translates to:
  /// **'IP-адрес принтера этикеток'**
  String get devParamLabelPrinterIp;

  /// No description provided for @devParamScannerMac.
  ///
  /// In ru, this message translates to:
  /// **'MAC-адрес сопряжённого Bluetooth-сканера'**
  String get devParamScannerMac;

  /// No description provided for @devParamScannerComPort.
  ///
  /// In ru, this message translates to:
  /// **'Последовательный порт сканера, например COM5'**
  String get devParamScannerComPort;

  /// No description provided for @devParamScaleComPort.
  ///
  /// In ru, this message translates to:
  /// **'Последовательный порт весов, например COM3'**
  String get devParamScaleComPort;

  /// No description provided for @devParamDrawerComPort.
  ///
  /// In ru, this message translates to:
  /// **'Последовательный порт интерфейсной платы ящика'**
  String get devParamDrawerComPort;

  /// No description provided for @devParamDisplayComPort.
  ///
  /// In ru, this message translates to:
  /// **'Последовательный порт дисплея покупателя'**
  String get devParamDisplayComPort;

  /// No description provided for @devParamKaspiIp.
  ///
  /// In ru, this message translates to:
  /// **'IP-адрес терминала Kaspi POS'**
  String get devParamKaspiIp;

  /// No description provided for @devParamKaspiPort.
  ///
  /// In ru, this message translates to:
  /// **'Порт терминала, обычно 8888'**
  String get devParamKaspiPort;

  /// No description provided for @devParamCameraId.
  ///
  /// In ru, this message translates to:
  /// **'Какую камеру использовать'**
  String get devParamCameraId;

  /// No description provided for @rcpTill.
  ///
  /// In ru, this message translates to:
  /// **'Касса'**
  String get rcpTill;

  /// No description provided for @rcpTillColon.
  ///
  /// In ru, this message translates to:
  /// **'Касса:'**
  String get rcpTillColon;

  /// No description provided for @rcpReceiptNo.
  ///
  /// In ru, this message translates to:
  /// **'Чек №'**
  String get rcpReceiptNo;

  /// No description provided for @rcpCashier.
  ///
  /// In ru, this message translates to:
  /// **'Кассир:'**
  String get rcpCashier;

  /// No description provided for @rcpCustomer.
  ///
  /// In ru, this message translates to:
  /// **'Клиент:'**
  String get rcpCustomer;

  /// No description provided for @rcpDate.
  ///
  /// In ru, this message translates to:
  /// **'Дата:'**
  String get rcpDate;

  /// No description provided for @rcpBinIin.
  ///
  /// In ru, this message translates to:
  /// **'БИН/ИИН:'**
  String get rcpBinIin;

  /// No description provided for @rcpThankYou.
  ///
  /// In ru, this message translates to:
  /// **'Спасибо за покупку!'**
  String get rcpThankYou;

  /// No description provided for @rcpSale.
  ///
  /// In ru, this message translates to:
  /// **'ПРОДАЖА'**
  String get rcpSale;

  /// No description provided for @rcpSubtotal.
  ///
  /// In ru, this message translates to:
  /// **'Подытог:'**
  String get rcpSubtotal;

  /// No description provided for @rcpDiscount.
  ///
  /// In ru, this message translates to:
  /// **'Скидка:'**
  String get rcpDiscount;

  /// No description provided for @rcpServiceFee.
  ///
  /// In ru, this message translates to:
  /// **'Сервисный сбор:'**
  String get rcpServiceFee;

  /// No description provided for @rcpTotal.
  ///
  /// In ru, this message translates to:
  /// **'ИТОГО:'**
  String get rcpTotal;

  /// No description provided for @rcpChange.
  ///
  /// In ru, this message translates to:
  /// **'Сдача:'**
  String get rcpChange;

  /// No description provided for @rcpCash.
  ///
  /// In ru, this message translates to:
  /// **'НАЛИЧНЫМИ'**
  String get rcpCash;

  /// No description provided for @rcpCard.
  ///
  /// In ru, this message translates to:
  /// **'КАРТА'**
  String get rcpCard;

  /// No description provided for @rcpQuantityShort.
  ///
  /// In ru, this message translates to:
  /// **'шт'**
  String get rcpQuantityShort;

  /// No description provided for @rcpRefund.
  ///
  /// In ru, this message translates to:
  /// **'ВОЗВРАТ'**
  String get rcpRefund;

  /// No description provided for @rcpRefundNo.
  ///
  /// In ru, this message translates to:
  /// **'Возврат №'**
  String get rcpRefundNo;

  /// No description provided for @rcpSaleReceiptNo.
  ///
  /// In ru, this message translates to:
  /// **'Чек продажи №'**
  String get rcpSaleReceiptNo;

  /// No description provided for @rcpDuplicate.
  ///
  /// In ru, this message translates to:
  /// **'*** ДУБЛИКАТ ***'**
  String get rcpDuplicate;

  /// No description provided for @rcpTable.
  ///
  /// In ru, this message translates to:
  /// **'Стол:'**
  String get rcpTable;

  /// No description provided for @rcpWaiter.
  ///
  /// In ru, this message translates to:
  /// **'Официант:'**
  String get rcpWaiter;

  /// No description provided for @rcpGuests.
  ///
  /// In ru, this message translates to:
  /// **'Гостей:'**
  String get rcpGuests;

  /// No description provided for @rcpFiscalReceipt.
  ///
  /// In ru, this message translates to:
  /// **'ФИСКАЛЬНЫЙ ЧЕК'**
  String get rcpFiscalReceipt;

  /// No description provided for @rcpNonFiscalReceipt.
  ///
  /// In ru, this message translates to:
  /// **'НЕФИСКАЛЬНЫЙ ЧЕК'**
  String get rcpNonFiscalReceipt;

  /// No description provided for @rcpNotFiscalDocument.
  ///
  /// In ru, this message translates to:
  /// **'НЕ ФИСКАЛЬНЫЙ ДОКУМЕНТ'**
  String get rcpNotFiscalDocument;

  /// No description provided for @rcpFiscalSign.
  ///
  /// In ru, this message translates to:
  /// **'ФИСК. ПРИЗНАК:'**
  String get rcpFiscalSign;

  /// No description provided for @rcpFiscalFn.
  ///
  /// In ru, this message translates to:
  /// **'ФН:'**
  String get rcpFiscalFn;

  /// No description provided for @rcpFiscalRnm.
  ///
  /// In ru, this message translates to:
  /// **'РНМ:'**
  String get rcpFiscalRnm;

  /// No description provided for @rcpFiscalZnm.
  ///
  /// In ru, this message translates to:
  /// **'ЗНМ:'**
  String get rcpFiscalZnm;

  /// No description provided for @rcpFiscalTime.
  ///
  /// In ru, this message translates to:
  /// **'ВРЕМЯ:'**
  String get rcpFiscalTime;

  /// No description provided for @rcpOfdName.
  ///
  /// In ru, this message translates to:
  /// **'ОФД'**
  String get rcpOfdName;

  /// No description provided for @rcpOffline.
  ///
  /// In ru, this message translates to:
  /// **'*** ОФФЛАЙН ***'**
  String get rcpOffline;

  /// No description provided for @rcpVerifyAt.
  ///
  /// In ru, this message translates to:
  /// **'Для проверки чека зайдите на'**
  String get rcpVerifyAt;

  /// No description provided for @rcpCustomerTaxId.
  ///
  /// In ru, this message translates to:
  /// **'ИИН покупателя:'**
  String get rcpCustomerTaxId;

  /// No description provided for @rcpTaxA.
  ///
  /// In ru, this message translates to:
  /// **'ПО НАЛОГУ А:'**
  String get rcpTaxA;

  /// No description provided for @rcpFiscalOperatorNotSet.
  ///
  /// In ru, this message translates to:
  /// **'Фискальный оператор не настроен'**
  String get rcpFiscalOperatorNotSet;

  /// No description provided for @rcpFiscalModuleUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Модуль фискализации недоступен'**
  String get rcpFiscalModuleUnavailable;

  /// No description provided for @rcpDocumentNotIssued.
  ///
  /// In ru, this message translates to:
  /// **'Документ не оформлен — обратитесь к кассиру'**
  String get rcpDocumentNotIssued;

  /// No description provided for @rcpXReport.
  ///
  /// In ru, this message translates to:
  /// **'X-ОТЧЁТ'**
  String get rcpXReport;

  /// No description provided for @rcpZReport.
  ///
  /// In ru, this message translates to:
  /// **'Z-ОТЧЁТ'**
  String get rcpZReport;

  /// No description provided for @rcpInterim.
  ///
  /// In ru, this message translates to:
  /// **'ПРОМЕЖУТОЧНЫЙ (без гашения)'**
  String get rcpInterim;

  /// No description provided for @rcpShiftClose.
  ///
  /// In ru, this message translates to:
  /// **'ЗАКРЫТИЕ СМЕНЫ'**
  String get rcpShiftClose;

  /// No description provided for @rcpShiftStart.
  ///
  /// In ru, this message translates to:
  /// **'Начало:'**
  String get rcpShiftStart;

  /// No description provided for @rcpShiftEnd.
  ///
  /// In ru, this message translates to:
  /// **'Окончание:'**
  String get rcpShiftEnd;

  /// No description provided for @rcpSales.
  ///
  /// In ru, this message translates to:
  /// **'ПРОДАЖИ'**
  String get rcpSales;

  /// No description provided for @rcpRefunds.
  ///
  /// In ru, this message translates to:
  /// **'ВОЗВРАТЫ'**
  String get rcpRefunds;

  /// No description provided for @rcpCount.
  ///
  /// In ru, this message translates to:
  /// **'Количество:'**
  String get rcpCount;

  /// No description provided for @rcpAmount.
  ///
  /// In ru, this message translates to:
  /// **'Сумма:'**
  String get rcpAmount;

  /// No description provided for @rcpCashOps.
  ///
  /// In ru, this message translates to:
  /// **'ДЕНЕЖНЫЕ ОПЕРАЦИИ'**
  String get rcpCashOps;

  /// No description provided for @rcpOpeningFloat.
  ///
  /// In ru, this message translates to:
  /// **'На начало:'**
  String get rcpOpeningFloat;

  /// No description provided for @rcpSlipTitle.
  ///
  /// In ru, this message translates to:
  /// **'КВИТАНЦИЯ'**
  String get rcpSlipTitle;

  /// No description provided for @rcpType.
  ///
  /// In ru, this message translates to:
  /// **'Тип:'**
  String get rcpType;

  /// No description provided for @rcpComment.
  ///
  /// In ru, this message translates to:
  /// **'Комментарий:'**
  String get rcpComment;

  /// No description provided for @rcpCashIn.
  ///
  /// In ru, this message translates to:
  /// **'Приход:'**
  String get rcpCashIn;

  /// No description provided for @rcpCashOut.
  ///
  /// In ru, this message translates to:
  /// **'Расход:'**
  String get rcpCashOut;

  /// No description provided for @rcpTotalInDrawer.
  ///
  /// In ru, this message translates to:
  /// **'ИТОГО В КАССЕ:'**
  String get rcpTotalInDrawer;

  /// No description provided for @rcpCertificatesNotRevenue.
  ///
  /// In ru, this message translates to:
  /// **'СЕРТИФИКАТЫ (НЕ ВЫРУЧКА)'**
  String get rcpCertificatesNotRevenue;

  /// No description provided for @rcpCertIssuedDebt.
  ///
  /// In ru, this message translates to:
  /// **'Выпущено (долг кассы):'**
  String get rcpCertIssuedDebt;

  /// No description provided for @rcpCertRedeemed.
  ///
  /// In ru, this message translates to:
  /// **'Погашено (товаром):'**
  String get rcpCertRedeemed;

  /// No description provided for @rcpGiftCertificate.
  ///
  /// In ru, this message translates to:
  /// **'ПОДАРОЧНЫЙ СЕРТИФИКАТ'**
  String get rcpGiftCertificate;

  /// No description provided for @rcpCertNo.
  ///
  /// In ru, this message translates to:
  /// **'Сертификат №'**
  String get rcpCertNo;

  /// No description provided for @rcpCertFaceValue.
  ///
  /// In ru, this message translates to:
  /// **'Номинал:'**
  String get rcpCertFaceValue;

  /// No description provided for @rcpCertValidUntil.
  ///
  /// In ru, this message translates to:
  /// **'Действует до:'**
  String get rcpCertValidUntil;

  /// No description provided for @rcpCertNoExpiry.
  ///
  /// In ru, this message translates to:
  /// **'без срока'**
  String get rcpCertNoExpiry;

  /// No description provided for @rcpCertPinSet.
  ///
  /// In ru, this message translates to:
  /// **'ПИН задан'**
  String get rcpCertPinSet;

  /// No description provided for @rcpCertIssuedByRefund.
  ///
  /// In ru, this message translates to:
  /// **'Выпущен возвратом №'**
  String get rcpCertIssuedByRefund;

  /// No description provided for @rcpCertInsteadOf.
  ///
  /// In ru, this message translates to:
  /// **'Взамен сертификата'**
  String get rcpCertInsteadOf;

  /// No description provided for @rcpVat.
  ///
  /// In ru, this message translates to:
  /// **'НДС'**
  String get rcpVat;

  /// No description provided for @rcpSalesTax.
  ///
  /// In ru, this message translates to:
  /// **'Налог с продаж'**
  String get rcpSalesTax;

  /// No description provided for @rcpTaxExempt.
  ///
  /// In ru, this message translates to:
  /// **'Не облагается'**
  String get rcpTaxExempt;

  /// No description provided for @rcpTaxExemptMark.
  ///
  /// In ru, this message translates to:
  /// **'осв.'**
  String get rcpTaxExemptMark;

  /// No description provided for @taxSettingsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Налоги'**
  String get taxSettingsTitle;

  /// No description provided for @taxSettingsSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Ставки, юрисдикции и категории товаров'**
  String get taxSettingsSubtitle;

  /// No description provided for @taxSettingsIntro.
  ///
  /// In ru, this message translates to:
  /// **'Ставка не задаётся одним числом: она складывается из долей юрисдикций, в которых стоит касса, и зависит от категории товара и даты. Готовый набор можно взять пресетом и потом править.'**
  String get taxSettingsIntro;

  /// No description provided for @taxSettingsNotConfigured.
  ///
  /// In ru, this message translates to:
  /// **'Налог не настроен: касса считает ноль.'**
  String get taxSettingsNotConfigured;

  /// No description provided for @taxSettingsPresetSection.
  ///
  /// In ru, this message translates to:
  /// **'Готовый набор'**
  String get taxSettingsPresetSection;

  /// No description provided for @taxSettingsCountry.
  ///
  /// In ru, this message translates to:
  /// **'Страна'**
  String get taxSettingsCountry;

  /// No description provided for @taxSettingsRegion.
  ///
  /// In ru, this message translates to:
  /// **'Штат или область'**
  String get taxSettingsRegion;

  /// No description provided for @taxSettingsCity.
  ///
  /// In ru, this message translates to:
  /// **'Город'**
  String get taxSettingsCity;

  /// No description provided for @taxSettingsPreset.
  ///
  /// In ru, this message translates to:
  /// **'Набор'**
  String get taxSettingsPreset;

  /// No description provided for @taxSettingsApplyPreset.
  ///
  /// In ru, this message translates to:
  /// **'Применить набор'**
  String get taxSettingsApplyPreset;

  /// No description provided for @taxSettingsPresetReplaces.
  ///
  /// In ru, this message translates to:
  /// **'Применение заменит текущую настройку целиком. Сложить два набора нельзя: касса взяла бы двойной налог.'**
  String get taxSettingsPresetReplaces;

  /// No description provided for @taxSettingsPresetSource.
  ///
  /// In ru, this message translates to:
  /// **'Источник: {source}'**
  String taxSettingsPresetSource(String source);

  /// No description provided for @taxSettingsPresetValidFrom.
  ///
  /// In ru, this message translates to:
  /// **'Ставки действуют с {date}'**
  String taxSettingsPresetValidFrom(String date);

  /// No description provided for @taxSettingsPresetApplied.
  ///
  /// In ru, this message translates to:
  /// **'Набор применён'**
  String get taxSettingsPresetApplied;

  /// No description provided for @taxSettingsCurrentSection.
  ///
  /// In ru, this message translates to:
  /// **'Текущая настройка'**
  String get taxSettingsCurrentSection;

  /// No description provided for @taxSettingsRateForStandard.
  ///
  /// In ru, this message translates to:
  /// **'Обычный товар: {rate}%'**
  String taxSettingsRateForStandard(String rate);

  /// No description provided for @taxSettingsJurisdictions.
  ///
  /// In ru, this message translates to:
  /// **'Юрисдикции'**
  String get taxSettingsJurisdictions;

  /// No description provided for @taxSettingsCategories.
  ///
  /// In ru, this message translates to:
  /// **'Категории товаров'**
  String get taxSettingsCategories;

  /// No description provided for @taxSettingsTillLocation.
  ///
  /// In ru, this message translates to:
  /// **'Касса стоит здесь'**
  String get taxSettingsTillLocation;

  /// No description provided for @taxSettingsTillLocationHint.
  ///
  /// In ru, this message translates to:
  /// **'Отметок может быть несколько: город и спецрайоны. Вышестоящие добавляются сами.'**
  String get taxSettingsTillLocationHint;

  /// No description provided for @taxSettingsRules.
  ///
  /// In ru, this message translates to:
  /// **'Правила'**
  String get taxSettingsRules;

  /// No description provided for @taxSettingsRuleTaxed.
  ///
  /// In ru, this message translates to:
  /// **'облагается'**
  String get taxSettingsRuleTaxed;

  /// No description provided for @taxSettingsRuleZero.
  ///
  /// In ru, this message translates to:
  /// **'нулевая ставка'**
  String get taxSettingsRuleZero;

  /// No description provided for @taxSettingsRuleExempt.
  ///
  /// In ru, this message translates to:
  /// **'освобождено'**
  String get taxSettingsRuleExempt;

  /// No description provided for @taxSettingsAllCategories.
  ///
  /// In ru, this message translates to:
  /// **'все категории'**
  String get taxSettingsAllCategories;

  /// No description provided for @taxSettingsAddJurisdiction.
  ///
  /// In ru, this message translates to:
  /// **'Добавить юрисдикцию'**
  String get taxSettingsAddJurisdiction;

  /// No description provided for @taxSettingsAddCategory.
  ///
  /// In ru, this message translates to:
  /// **'Добавить категорию'**
  String get taxSettingsAddCategory;

  /// No description provided for @taxSettingsAddRule.
  ///
  /// In ru, this message translates to:
  /// **'Добавить правило'**
  String get taxSettingsAddRule;

  /// No description provided for @taxSettingsName.
  ///
  /// In ru, this message translates to:
  /// **'Название'**
  String get taxSettingsName;

  /// No description provided for @taxSettingsCode.
  ///
  /// In ru, this message translates to:
  /// **'Код'**
  String get taxSettingsCode;

  /// No description provided for @taxSettingsRate.
  ///
  /// In ru, this message translates to:
  /// **'Ставка, %'**
  String get taxSettingsRate;

  /// No description provided for @taxSettingsValidFrom.
  ///
  /// In ru, this message translates to:
  /// **'Действует с'**
  String get taxSettingsValidFrom;

  /// No description provided for @taxSettingsParent.
  ///
  /// In ru, this message translates to:
  /// **'Вышестоящая'**
  String get taxSettingsParent;

  /// No description provided for @taxSettingsNoParent.
  ///
  /// In ru, this message translates to:
  /// **'нет (корень)'**
  String get taxSettingsNoParent;

  /// No description provided for @taxSettingsLevel.
  ///
  /// In ru, this message translates to:
  /// **'Уровень'**
  String get taxSettingsLevel;

  /// No description provided for @taxSettingsLevelCountry.
  ///
  /// In ru, this message translates to:
  /// **'Страна'**
  String get taxSettingsLevelCountry;

  /// No description provided for @taxSettingsLevelState.
  ///
  /// In ru, this message translates to:
  /// **'Штат'**
  String get taxSettingsLevelState;

  /// No description provided for @taxSettingsLevelCounty.
  ///
  /// In ru, this message translates to:
  /// **'Округ'**
  String get taxSettingsLevelCounty;

  /// No description provided for @taxSettingsLevelCity.
  ///
  /// In ru, this message translates to:
  /// **'Город'**
  String get taxSettingsLevelCity;

  /// No description provided for @taxSettingsLevelDistrict.
  ///
  /// In ru, this message translates to:
  /// **'Спецрайон'**
  String get taxSettingsLevelDistrict;

  /// No description provided for @taxSettingsDelete.
  ///
  /// In ru, this message translates to:
  /// **'Удалить'**
  String get taxSettingsDelete;

  /// No description provided for @taxSettingsDeleteJurisdictionWarning.
  ///
  /// In ru, this message translates to:
  /// **'Вместе с ней уйдут её правила и вложенные юрисдикции.'**
  String get taxSettingsDeleteJurisdictionWarning;

  /// No description provided for @taxSettingsResponsibility.
  ///
  /// In ru, this message translates to:
  /// **'Числа из наборов собраны из открытых источников и названы ссылкой. За правильность налога отвечает налогоплательщик, а не программа.'**
  String get taxSettingsResponsibility;

  /// No description provided for @taxSettingsNoPresetsForCountry.
  ///
  /// In ru, this message translates to:
  /// **'Для этой страны готовых наборов нет — настройте вручную.'**
  String get taxSettingsNoPresetsForCountry;

  /// No description provided for @taxSettingsAdd.
  ///
  /// In ru, this message translates to:
  /// **'Добавить'**
  String get taxSettingsAdd;

  /// No description provided for @taxSettingsCancel.
  ///
  /// In ru, this message translates to:
  /// **'Отмена'**
  String get taxSettingsCancel;

  /// No description provided for @setupStoreAddressHint.
  ///
  /// In ru, this message translates to:
  /// **'ул. Абая, 10, Алматы'**
  String get setupStoreAddressHint;

  /// No description provided for @setupStoreAddressHelper.
  ///
  /// In ru, this message translates to:
  /// **'Печатается на чеке. Без него покупатель не увидит, где сделана покупка.'**
  String get setupStoreAddressHelper;

  /// No description provided for @countryKz.
  ///
  /// In ru, this message translates to:
  /// **'Казахстан'**
  String get countryKz;

  /// No description provided for @countryRu.
  ///
  /// In ru, this message translates to:
  /// **'Россия'**
  String get countryRu;

  /// No description provided for @countryKg.
  ///
  /// In ru, this message translates to:
  /// **'Кыргызстан'**
  String get countryKg;

  /// No description provided for @countryUz.
  ///
  /// In ru, this message translates to:
  /// **'Узбекистан'**
  String get countryUz;

  /// No description provided for @countryUs.
  ///
  /// In ru, this message translates to:
  /// **'США'**
  String get countryUs;

  /// No description provided for @countryTm.
  ///
  /// In ru, this message translates to:
  /// **'Туркменистан'**
  String get countryTm;

  /// No description provided for @currencyKzt.
  ///
  /// In ru, this message translates to:
  /// **'Казахстанский тенге'**
  String get currencyKzt;

  /// No description provided for @currencyRub.
  ///
  /// In ru, this message translates to:
  /// **'Российский рубль'**
  String get currencyRub;

  /// No description provided for @currencyKgs.
  ///
  /// In ru, this message translates to:
  /// **'Кыргызский сом'**
  String get currencyKgs;

  /// No description provided for @currencyUzs.
  ///
  /// In ru, this message translates to:
  /// **'Узбекский сум'**
  String get currencyUzs;

  /// No description provided for @currencyUsd.
  ///
  /// In ru, this message translates to:
  /// **'Доллар США'**
  String get currencyUsd;

  /// No description provided for @currencyTmt.
  ///
  /// In ru, this message translates to:
  /// **'Туркменский манат'**
  String get currencyTmt;

  /// No description provided for @setupStepSalesTax.
  ///
  /// In ru, this message translates to:
  /// **'Налог с продаж'**
  String get setupStepSalesTax;

  /// No description provided for @setupSalesTaxPayerTitle.
  ///
  /// In ru, this message translates to:
  /// **'Собираю налог с продаж'**
  String get setupSalesTaxPayerTitle;

  /// No description provided for @setupSalesTaxPayerSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Ставки задаются по юрисдикциям в «Настройки → Налоги»'**
  String get setupSalesTaxPayerSubtitle;

  /// No description provided for @setupSalesTaxPayerDescription.
  ///
  /// In ru, this message translates to:
  /// **'Налог добавляется сверх цены на ценнике и печатается на чеке отдельной строкой.'**
  String get setupSalesTaxPayerDescription;

  /// No description provided for @setupSalesTaxNonPayerTitle.
  ///
  /// In ru, this message translates to:
  /// **'Без налога с продаж'**
  String get setupSalesTaxNonPayerTitle;

  /// No description provided for @setupSalesTaxNonPayerSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'К цене ничего не добавляется'**
  String get setupSalesTaxNonPayerSubtitle;

  /// No description provided for @setupSalesTaxNonPayerDescription.
  ///
  /// In ru, this message translates to:
  /// **'К цене ничего не добавляется, и строки налога на чеке нет.'**
  String get setupSalesTaxNonPayerDescription;

  /// No description provided for @bootLoadingConfig.
  ///
  /// In ru, this message translates to:
  /// **'Загрузка конфигурации...'**
  String get bootLoadingConfig;

  /// No description provided for @bootCheckingPosKey.
  ///
  /// In ru, this message translates to:
  /// **'Проверка ключа POS...'**
  String get bootCheckingPosKey;

  /// No description provided for @bootLoadingAgents.
  ///
  /// In ru, this message translates to:
  /// **'Загрузка контрагентов...'**
  String get bootLoadingAgents;

  /// No description provided for @bootLoadingAccounts.
  ///
  /// In ru, this message translates to:
  /// **'Загрузка счетов...'**
  String get bootLoadingAccounts;

  /// No description provided for @bootInitialisingDatabase.
  ///
  /// In ru, this message translates to:
  /// **'Инициализация базы данных...'**
  String get bootInitialisingDatabase;

  /// No description provided for @bootLoadingCashiers.
  ///
  /// In ru, this message translates to:
  /// **'Загрузка кассиров...'**
  String get bootLoadingCashiers;

  /// No description provided for @bootLoadingPosData.
  ///
  /// In ru, this message translates to:
  /// **'Загрузка данных POS...'**
  String get bootLoadingPosData;

  /// No description provided for @bootLoadingProducts.
  ///
  /// In ru, this message translates to:
  /// **'Загрузка товаров...'**
  String get bootLoadingProducts;

  /// No description provided for @bootCheckingReceiptNumbers.
  ///
  /// In ru, this message translates to:
  /// **'Проверка нумерации чеков...'**
  String get bootCheckingReceiptNumbers;

  /// No description provided for @bootCheckingLicence.
  ///
  /// In ru, this message translates to:
  /// **'Проверка лицензии...'**
  String get bootCheckingLicence;

  /// No description provided for @bootCheckingReports.
  ///
  /// In ru, this message translates to:
  /// **'Проверка отчётов...'**
  String get bootCheckingReports;

  /// No description provided for @bootFinishingInitialisation.
  ///
  /// In ru, this message translates to:
  /// **'Завершение инициализации...'**
  String get bootFinishingInitialisation;

  /// No description provided for @bootStartingBackgroundJobs.
  ///
  /// In ru, this message translates to:
  /// **'Запуск фоновых задач...'**
  String get bootStartingBackgroundJobs;

  /// No description provided for @bootReady.
  ///
  /// In ru, this message translates to:
  /// **'Готово'**
  String get bootReady;

  /// No description provided for @bootDataLoaded.
  ///
  /// In ru, this message translates to:
  /// **'Данные загружены'**
  String get bootDataLoaded;

  /// No description provided for @bootTillNotResponding.
  ///
  /// In ru, this message translates to:
  /// **'Касса не отвечает: {code}'**
  String bootTillNotResponding(String code);

  /// No description provided for @bootDownloadingBackup.
  ///
  /// In ru, this message translates to:
  /// **'Скачивание бэкапа...'**
  String get bootDownloadingBackup;

  /// No description provided for @bootBackupDownloadFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось скачать бэкап'**
  String get bootBackupDownloadFailed;

  /// No description provided for @bootRestoringDatabase.
  ///
  /// In ru, this message translates to:
  /// **'Восстановление базы данных...'**
  String get bootRestoringDatabase;

  /// No description provided for @bootDatabaseRestoreFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось восстановить базу данных'**
  String get bootDatabaseRestoreFailed;

  /// No description provided for @bootApplyingPosKey.
  ///
  /// In ru, this message translates to:
  /// **'Настройка ключа кассы...'**
  String get bootApplyingPosKey;

  /// No description provided for @bootRestoreDone.
  ///
  /// In ru, this message translates to:
  /// **'Восстановление завершено'**
  String get bootRestoreDone;

  /// No description provided for @bootCreatingBackup.
  ///
  /// In ru, this message translates to:
  /// **'Создание бэкапа...'**
  String get bootCreatingBackup;

  /// No description provided for @bootBackupCreateFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось создать бэкап'**
  String get bootBackupCreateFailed;

  /// No description provided for @bootBackupDone.
  ///
  /// In ru, this message translates to:
  /// **'Бэкап создан и загружен'**
  String get bootBackupDone;

  /// No description provided for @bootLoadingUsers.
  ///
  /// In ru, this message translates to:
  /// **'Загрузка пользователей...'**
  String get bootLoadingUsers;

  /// No description provided for @bootLoadingCategories.
  ///
  /// In ru, this message translates to:
  /// **'Загрузка категорий...'**
  String get bootLoadingCategories;

  /// No description provided for @bootLoadingSettings.
  ///
  /// In ru, this message translates to:
  /// **'Загрузка настроек...'**
  String get bootLoadingSettings;

  /// No description provided for @bootSyncDone.
  ///
  /// In ru, this message translates to:
  /// **'Синхронизация завершена'**
  String get bootSyncDone;

  /// No description provided for @bootFailed.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка'**
  String get bootFailed;

  /// No description provided for @countryDeu.
  ///
  /// In ru, this message translates to:
  /// **'Германия'**
  String get countryDeu;

  /// No description provided for @currencyDeu.
  ///
  /// In ru, this message translates to:
  /// **'Евро'**
  String get currencyDeu;

  /// No description provided for @countryFra.
  ///
  /// In ru, this message translates to:
  /// **'Франция'**
  String get countryFra;

  /// No description provided for @currencyFra.
  ///
  /// In ru, this message translates to:
  /// **'Евро'**
  String get currencyFra;

  /// No description provided for @countryEsp.
  ///
  /// In ru, this message translates to:
  /// **'Испания'**
  String get countryEsp;

  /// No description provided for @currencyEsp.
  ///
  /// In ru, this message translates to:
  /// **'Евро'**
  String get currencyEsp;

  /// No description provided for @countryIta.
  ///
  /// In ru, this message translates to:
  /// **'Италия'**
  String get countryIta;

  /// No description provided for @currencyIta.
  ///
  /// In ru, this message translates to:
  /// **'Евро'**
  String get currencyIta;

  /// No description provided for @countryGbr.
  ///
  /// In ru, this message translates to:
  /// **'Великобритания'**
  String get countryGbr;

  /// No description provided for @currencyGbr.
  ///
  /// In ru, this message translates to:
  /// **'Фунт стерлингов'**
  String get currencyGbr;

  /// No description provided for @countryPol.
  ///
  /// In ru, this message translates to:
  /// **'Польша'**
  String get countryPol;

  /// No description provided for @currencyPol.
  ///
  /// In ru, this message translates to:
  /// **'Польский злотый'**
  String get currencyPol;

  /// No description provided for @countryTur.
  ///
  /// In ru, this message translates to:
  /// **'Турция'**
  String get countryTur;

  /// No description provided for @currencyTur.
  ///
  /// In ru, this message translates to:
  /// **'Турецкая лира'**
  String get currencyTur;

  /// No description provided for @countryChn.
  ///
  /// In ru, this message translates to:
  /// **'Китай'**
  String get countryChn;

  /// No description provided for @currencyChn.
  ///
  /// In ru, this message translates to:
  /// **'Китайский юань'**
  String get currencyChn;

  /// No description provided for @countryJpn.
  ///
  /// In ru, this message translates to:
  /// **'Япония'**
  String get countryJpn;

  /// No description provided for @currencyJpn.
  ///
  /// In ru, this message translates to:
  /// **'Японская иена'**
  String get currencyJpn;

  /// No description provided for @countryKor.
  ///
  /// In ru, this message translates to:
  /// **'Южная Корея'**
  String get countryKor;

  /// No description provided for @currencyKor.
  ///
  /// In ru, this message translates to:
  /// **'Южнокорейская вона'**
  String get currencyKor;

  /// No description provided for @countryAre.
  ///
  /// In ru, this message translates to:
  /// **'ОАЭ'**
  String get countryAre;

  /// No description provided for @currencyAre.
  ///
  /// In ru, this message translates to:
  /// **'Дирхам ОАЭ'**
  String get currencyAre;

  /// No description provided for @countrySau.
  ///
  /// In ru, this message translates to:
  /// **'Саудовская Аравия'**
  String get countrySau;

  /// No description provided for @currencySau.
  ///
  /// In ru, this message translates to:
  /// **'Саудовский риял'**
  String get currencySau;

  /// No description provided for @countryInd.
  ///
  /// In ru, this message translates to:
  /// **'Индия'**
  String get countryInd;

  /// No description provided for @currencyInd.
  ///
  /// In ru, this message translates to:
  /// **'Индийская рупия'**
  String get currencyInd;

  /// No description provided for @countryCan.
  ///
  /// In ru, this message translates to:
  /// **'Канада'**
  String get countryCan;

  /// No description provided for @currencyCan.
  ///
  /// In ru, this message translates to:
  /// **'Канадский доллар'**
  String get currencyCan;

  /// No description provided for @countryAus.
  ///
  /// In ru, this message translates to:
  /// **'Австралия'**
  String get countryAus;

  /// No description provided for @currencyAus.
  ///
  /// In ru, this message translates to:
  /// **'Австралийский доллар'**
  String get currencyAus;

  /// No description provided for @agentPaymentAccepted.
  ///
  /// In ru, this message translates to:
  /// **'Оплата принята'**
  String get agentPaymentAccepted;

  /// No description provided for @catalogCategoryHasChildren.
  ///
  /// In ru, this message translates to:
  /// **'Категория содержит подкатегории'**
  String get catalogCategoryHasChildren;

  /// No description provided for @creditOutstanding.
  ///
  /// In ru, this message translates to:
  /// **'Осталось: {amount}'**
  String creditOutstanding(String amount);

  /// No description provided for @creditTakePayment.
  ///
  /// In ru, this message translates to:
  /// **'Принять платёж'**
  String get creditTakePayment;

  /// No description provided for @creditPrintContract.
  ///
  /// In ru, this message translates to:
  /// **'Печать договора'**
  String get creditPrintContract;

  /// No description provided for @creditPaymentFor.
  ///
  /// In ru, this message translates to:
  /// **'Платёж по {number}'**
  String creditPaymentFor(String number);

  /// No description provided for @creditOutstandingOnContract.
  ///
  /// In ru, this message translates to:
  /// **'Осталось по договору: {amount}'**
  String creditOutstandingOnContract(String amount);

  /// No description provided for @creditPayInFull.
  ///
  /// In ru, this message translates to:
  /// **'Погасить целиком'**
  String get creditPayInFull;

  /// No description provided for @creditAccept.
  ///
  /// In ru, this message translates to:
  /// **'Принять'**
  String get creditAccept;

  /// No description provided for @displayProduct.
  ///
  /// In ru, this message translates to:
  /// **'Товар'**
  String get displayProduct;

  /// No description provided for @markupSaved.
  ///
  /// In ru, this message translates to:
  /// **'Наценки сохранены: {count} категорий с наценкой'**
  String markupSaved(int count);

  /// No description provided for @genericErrorWith.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка: {detail}'**
  String genericErrorWith(String detail);

  /// No description provided for @serviceAttachPhoto.
  ///
  /// In ru, this message translates to:
  /// **'Фото'**
  String get serviceAttachPhoto;

  /// No description provided for @serviceAttachVideo.
  ///
  /// In ru, this message translates to:
  /// **'Видео'**
  String get serviceAttachVideo;

  /// No description provided for @shiftCorrectionReceipt.
  ///
  /// In ru, this message translates to:
  /// **'Чек коррекции'**
  String get shiftCorrectionReceipt;

  /// No description provided for @supplierChoose.
  ///
  /// In ru, this message translates to:
  /// **'Выберите поставщика'**
  String get supplierChoose;

  /// No description provided for @supplierProduct.
  ///
  /// In ru, this message translates to:
  /// **'Товар'**
  String get supplierProduct;

  /// No description provided for @supplierStock.
  ///
  /// In ru, this message translates to:
  /// **'Остаток'**
  String get supplierStock;

  /// No description provided for @supplierOrderQty.
  ///
  /// In ru, this message translates to:
  /// **'Заказать'**
  String get supplierOrderQty;

  /// No description provided for @supplierCreateRequest.
  ///
  /// In ru, this message translates to:
  /// **'Сформировать заявку'**
  String get supplierCreateRequest;

  /// No description provided for @supplierNeedQuantity.
  ///
  /// In ru, this message translates to:
  /// **'Укажите количество хотя бы по одному товару'**
  String get supplierNeedQuantity;

  /// No description provided for @unitMonthsShort.
  ///
  /// In ru, this message translates to:
  /// **'{count} мес.'**
  String unitMonthsShort(int count);

  /// No description provided for @unitDaysShort.
  ///
  /// In ru, this message translates to:
  /// **'{count} дн.'**
  String unitDaysShort(int count);

  /// No description provided for @displayWelcome.
  ///
  /// In ru, this message translates to:
  /// **'Добро пожаловать!'**
  String get displayWelcome;

  /// No description provided for @displayWelcomeSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Мы рады видеть вас'**
  String get displayWelcomeSubtitle;

  /// No description provided for @displayPromoFree.
  ///
  /// In ru, this message translates to:
  /// **'Акция · бесплатно'**
  String get displayPromoFree;

  /// No description provided for @displayDiscountAmount.
  ///
  /// In ru, this message translates to:
  /// **'Скидка −{amount}'**
  String displayDiscountAmount(String amount);

  /// No description provided for @displayWindowTitle.
  ///
  /// In ru, this message translates to:
  /// **'Экран покупателя'**
  String get displayWindowTitle;

  /// No description provided for @shiftXReportPrinted.
  ///
  /// In ru, this message translates to:
  /// **'X-отчёт распечатан'**
  String get shiftXReportPrinted;

  /// No description provided for @shiftXReportPrintedOffline.
  ///
  /// In ru, this message translates to:
  /// **'X-отчёт распечатан (фискальный X в очереди, связи нет)'**
  String get shiftXReportPrintedOffline;

  /// No description provided for @shiftXReportFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось распечатать X-отчёт'**
  String get shiftXReportFailed;

  /// No description provided for @creditContractNotFound.
  ///
  /// In ru, this message translates to:
  /// **'Договора {number} в базе кассы нет'**
  String creditContractNotFound(String number);

  /// No description provided for @creditOverdue.
  ///
  /// In ru, this message translates to:
  /// **'ПРОСРОЧЕНО: {amount} ({count} платежей)'**
  String creditOverdue(String amount, int count);

  /// No description provided for @creditNextPayment.
  ///
  /// In ru, this message translates to:
  /// **'Ближайший платёж {date}: {amount}'**
  String creditNextPayment(String date, String amount);

  /// No description provided for @creditNoTillAccount.
  ///
  /// In ru, this message translates to:
  /// **'У кассы нет счёта — принять деньги некуда'**
  String get creditNoTillAccount;

  /// No description provided for @creditContractClosed.
  ///
  /// In ru, this message translates to:
  /// **'Договор {number} закрыт'**
  String creditContractClosed(String number);

  /// No description provided for @creditPartiallyPaid.
  ///
  /// In ru, this message translates to:
  /// **'Принято {paid}, осталось {left}'**
  String creditPartiallyPaid(String paid, String left);

  /// No description provided for @creditPaymentAmount.
  ///
  /// In ru, this message translates to:
  /// **'Сумма платежа'**
  String get creditPaymentAmount;

  /// No description provided for @serviceWarrantyAndQuality.
  ///
  /// In ru, this message translates to:
  /// **'Гарантия и качество'**
  String get serviceWarrantyAndQuality;

  /// No description provided for @serviceWarrantyDays.
  ///
  /// In ru, this message translates to:
  /// **'Гарантия: {days} дн.'**
  String serviceWarrantyDays(int days);

  /// No description provided for @serviceWarrantyNotSet.
  ///
  /// In ru, this message translates to:
  /// **'Гарантия не установлена'**
  String get serviceWarrantyNotSet;

  /// No description provided for @serviceQualityRatingTitle.
  ///
  /// In ru, this message translates to:
  /// **'Оценка качества'**
  String get serviceQualityRatingTitle;

  /// No description provided for @serviceQualityRatingValue.
  ///
  /// In ru, this message translates to:
  /// **'Оценка: {rating}/5'**
  String serviceQualityRatingValue(int rating);

  /// No description provided for @serviceRepairMedia.
  ///
  /// In ru, this message translates to:
  /// **'Фото/видео ремонта'**
  String get serviceRepairMedia;

  /// No description provided for @serviceNoRepairMedia.
  ///
  /// In ru, this message translates to:
  /// **'Нет медиа ремонта'**
  String get serviceNoRepairMedia;

  /// No description provided for @supplierLabel.
  ///
  /// In ru, this message translates to:
  /// **'Поставщик:'**
  String get supplierLabel;

  /// No description provided for @supplierLinesToOrder.
  ///
  /// In ru, this message translates to:
  /// **'Позиций к заказу: {count}'**
  String supplierLinesToOrder(int count);

  /// No description provided for @supplierRequestCreated.
  ///
  /// In ru, this message translates to:
  /// **'Заявка сформирована: {count} поз.'**
  String supplierRequestCreated(int count);

  /// No description provided for @modifierRequired.
  ///
  /// In ru, this message translates to:
  /// **'Обязательно'**
  String get modifierRequired;

  /// No description provided for @modifierMax.
  ///
  /// In ru, this message translates to:
  /// **'макс. {count}'**
  String modifierMax(int count);

  /// No description provided for @writeoffReasonUnspecified.
  ///
  /// In ru, this message translates to:
  /// **'Не указана'**
  String get writeoffReasonUnspecified;

  /// No description provided for @labelSampleProduct.
  ///
  /// In ru, this message translates to:
  /// **'Образец товара'**
  String get labelSampleProduct;

  /// No description provided for @markupCategoryNumbered.
  ///
  /// In ru, this message translates to:
  /// **'Категория #{id}'**
  String markupCategoryNumbered(int id);

  /// No description provided for @salePolicyForbids.
  ///
  /// In ru, this message translates to:
  /// **'Действие запрещено настройками POS (Настройки → Политика продаж)'**
  String get salePolicyForbids;

  /// No description provided for @labelPrintFailed.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка печати этикетки'**
  String get labelPrintFailed;

  /// No description provided for @labelPrintFromTillOnly.
  ///
  /// In ru, this message translates to:
  /// **'Печать этикеток — с кассы, не с терминала'**
  String get labelPrintFromTillOnly;

  /// No description provided for @orphanQrTillNotRegistered.
  ///
  /// In ru, this message translates to:
  /// **'База кассы не зарегистрирована — неразобранные деньги по QR спросить не у кого'**
  String get orphanQrTillNotRegistered;

  /// No description provided for @stockLowStockReorder.
  ///
  /// In ru, this message translates to:
  /// **'Дозаказ товаров с низким остатком'**
  String get stockLowStockReorder;

  /// No description provided for @serviceNoteNeedsApproval.
  ///
  /// In ru, this message translates to:
  /// **'Требует согласования клиента'**
  String get serviceNoteNeedsApproval;

  /// No description provided for @deferredFromTill.
  ///
  /// In ru, this message translates to:
  /// **'касса {id}'**
  String deferredFromTill(String id);

  /// No description provided for @dishSummary.
  ///
  /// In ru, this message translates to:
  /// **'Ингредиентов: {count}, себестоимость: {cost}'**
  String dishSummary(int count, String cost);

  /// No description provided for @prepaymentIssueTo.
  ///
  /// In ru, this message translates to:
  /// **'Выдача аванса покупателю ({name})'**
  String prepaymentIssueTo(String name);

  /// No description provided for @prepaymentFrom.
  ///
  /// In ru, this message translates to:
  /// **'Аванс покупателя ({name})'**
  String prepaymentFrom(String name);

  /// No description provided for @prepaymentRefundTo.
  ///
  /// In ru, this message translates to:
  /// **'Возврат аванса покупателю ({name})'**
  String prepaymentRefundTo(String name);

  /// No description provided for @setupPartOrganization.
  ///
  /// In ru, this message translates to:
  /// **'организация'**
  String get setupPartOrganization;

  /// No description provided for @setupPartTill.
  ///
  /// In ru, this message translates to:
  /// **'касса'**
  String get setupPartTill;

  /// No description provided for @setupPartFiscal.
  ///
  /// In ru, this message translates to:
  /// **'фискализация'**
  String get setupPartFiscal;

  /// No description provided for @setupPartEquipment.
  ///
  /// In ru, this message translates to:
  /// **'оборудование'**
  String get setupPartEquipment;

  /// No description provided for @setupPartTerminals.
  ///
  /// In ru, this message translates to:
  /// **'платёжные терминалы'**
  String get setupPartTerminals;

  /// No description provided for @setupPartRules.
  ///
  /// In ru, this message translates to:
  /// **'правила'**
  String get setupPartRules;

  /// No description provided for @setupPartUser.
  ///
  /// In ru, this message translates to:
  /// **'пользователь'**
  String get setupPartUser;

  /// No description provided for @customerPaymentNote.
  ///
  /// In ru, this message translates to:
  /// **'Погашение долга / оплата ({name})'**
  String customerPaymentNote(String name);

  /// No description provided for @chatMembersUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Список участников не загрузился'**
  String get chatMembersUnavailable;

  /// No description provided for @chatMe.
  ///
  /// In ru, this message translates to:
  /// **'Я'**
  String get chatMe;

  /// No description provided for @setPolicyBigAmountLimit.
  ///
  /// In ru, this message translates to:
  /// **'Потолок суммы чека'**
  String get setPolicyBigAmountLimit;

  /// No description provided for @setPolicyBigAmountLimitDesc.
  ///
  /// In ru, this message translates to:
  /// **'Выше этой суммы касса просит разрешения. Пусто — {fallback}.'**
  String setPolicyBigAmountLimitDesc(String fallback);

  /// No description provided for @cashRefusedNotPositive.
  ///
  /// In ru, this message translates to:
  /// **'Сумма должна быть больше нуля'**
  String get cashRefusedNotPositive;

  /// No description provided for @cashRefusedAboveCeiling.
  ///
  /// In ru, this message translates to:
  /// **'Сумма выше потолка кассы ({limit}). Поднимите потолок в настройках или включите разрешение на крупные суммы.'**
  String cashRefusedAboveCeiling(String limit);

  /// No description provided for @errorProductHasNoPrice.
  ///
  /// In ru, this message translates to:
  /// **'У товара «{name}» не заведена цена — продать его нельзя. Заведите цену в каталоге.'**
  String errorProductHasNoPrice(String name);

  /// No description provided for @sellingHoursTitle.
  ///
  /// In ru, this message translates to:
  /// **'Часы запрета продажи'**
  String get sellingHoursTitle;

  /// No description provided for @sellingHoursAdd.
  ///
  /// In ru, this message translates to:
  /// **'Добавить окно'**
  String get sellingHoursAdd;

  /// No description provided for @sellingHoursCategory.
  ///
  /// In ru, this message translates to:
  /// **'Категория'**
  String get sellingHoursCategory;

  /// No description provided for @sellingHoursFrom.
  ///
  /// In ru, this message translates to:
  /// **'С (ЧЧ:ММ)'**
  String get sellingHoursFrom;

  /// No description provided for @sellingHoursTo.
  ///
  /// In ru, this message translates to:
  /// **'До (ЧЧ:ММ)'**
  String get sellingHoursTo;

  /// No description provided for @sellingHoursActive.
  ///
  /// In ru, this message translates to:
  /// **'Запрет действует'**
  String get sellingHoursActive;

  /// No description provided for @sellingHoursBanned.
  ///
  /// In ru, this message translates to:
  /// **'Продажа запрещена {window}'**
  String sellingHoursBanned(String window);

  /// No description provided for @sellingHoursOff.
  ///
  /// In ru, this message translates to:
  /// **'Окно {window} выключено'**
  String sellingHoursOff(String window);

  /// No description provided for @sellingHoursBroken.
  ///
  /// In ru, this message translates to:
  /// **'Часы «{window}» не разобраны — запрет не работает'**
  String sellingHoursBroken(String window);

  /// No description provided for @sellingHoursBadTime.
  ///
  /// In ru, this message translates to:
  /// **'Время записывается как ЧЧ:ММ, например 23:00'**
  String get sellingHoursBadTime;

  /// No description provided for @sellingHoursPreviewDay.
  ///
  /// In ru, this message translates to:
  /// **'Запрет внутри суток: {window}'**
  String sellingHoursPreviewDay(String window);

  /// No description provided for @sellingHoursPreviewNight.
  ///
  /// In ru, this message translates to:
  /// **'Ночной запрет через полночь: {window}'**
  String sellingHoursPreviewNight(String window);

  /// No description provided for @sellingHoursExplainer.
  ///
  /// In ru, this message translates to:
  /// **'Часы задаёте вы: закон в каждой стране свой и меняется. Запрет на категорию действует и на все вложенные в неё.'**
  String get sellingHoursExplainer;

  /// No description provided for @sellingHoursNoCategories.
  ///
  /// In ru, this message translates to:
  /// **'Сначала заведите категории в каталоге — запрет ставится на категорию.'**
  String get sellingHoursNoCategories;

  /// No description provided for @sellingHoursCategoryGone.
  ///
  /// In ru, this message translates to:
  /// **'Категория #{id} удалена'**
  String sellingHoursCategoryGone(int id);

  /// No description provided for @errorSellingHoursBanned.
  ///
  /// In ru, this message translates to:
  /// **'«{category}» сейчас продавать нельзя: запрет {window}.'**
  String errorSellingHoursBanned(String category, String window);

  /// No description provided for @errorSellingHoursBannedNoWindow.
  ///
  /// In ru, this message translates to:
  /// **'«{category}» сейчас продавать нельзя.'**
  String errorSellingHoursBannedNoWindow(String category);

  /// No description provided for @generalSettingsStoreAddress.
  ///
  /// In ru, this message translates to:
  /// **'Адрес торговой точки'**
  String get generalSettingsStoreAddress;

  /// No description provided for @generalSettingsStoreAddressHint.
  ///
  /// In ru, this message translates to:
  /// **'Печатается на чеке. Поменяйте, если магазин переехал.'**
  String get generalSettingsStoreAddressHint;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'kk', 'ky', 'ru', 'uz'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'kk':
      return AppLocalizationsKk();
    case 'ky':
      return AppLocalizationsKy();
    case 'ru':
      return AppLocalizationsRu();
    case 'uz':
      return AppLocalizationsUz();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
