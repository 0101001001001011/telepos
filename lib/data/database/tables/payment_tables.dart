import 'package:drift/drift.dart';
import 'package:telepos/data/database/converters/decimal_converter.dart';

class Payments extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get userId => integer()();

  IntColumn get receiptNo => integer().nullable()();

  IntColumn get posId => integer().nullable()();

  IntColumn get refundLocalId => integer().nullable()();

  IntColumn get customerLocalId => integer().nullable()();

  IntColumn get payeeAccountId => integer()();

  RealColumn get amount => real().map(const DecimalConverter())();

  IntColumn get time => integer()();

  IntColumn get state => integer().nullable()();

  TextColumn get approvalCode => text().nullable()();

  TextColumn get cardMask => text().nullable()();

  TextColumn get terminalTransactionId => text().nullable()();

  /// Вид оплаты — строка справочника `PaymentKinds` (задача 14, v41).
  ///
  /// # Почему **nullable**, и это осознанно
  ///
  /// Строку со снесённым счётом классифицировать **нечем**:
  /// `PaymentKindDerivation.derive` отвечает по роду счёта, а рода нет.
  /// `NOT NULL` с умолчанием «наличные» соврал бы про историческую оплату
  /// картой — и соврал бы в отчёте смены, где эта строка попала бы в
  /// выручку наличными. Пустое поле читается как «не знаю» и видно; ложное
  /// «наличные» не видно никогда.
  ///
  /// # Правило чтения
  ///
  /// Заполнено — **читать его**, не перевыводить. Две строки одного чека
  /// на один счёт с разными видами законны и нужны (ровно поэтому снят
  /// `payment_account_conflict`), и вывод по счёту слил бы их в один вид.
  IntColumn get kindId => integer().nullable()();

  /// Номер строки внутри попытки оплаты — **считается от нуля на каждой
  /// попытке**.
  ///
  /// Разбор и цена — в оговорке к [uniqueKeys] ниже. Читать её обязательно
  /// прежде, чем менять способ вычисления.
  IntColumn get seq => integer().withDefault(const Constant(0))();

  /// Ключ команды, которой строка написана.
  ///
  /// Тот же ключ, которым занимается чек (`Sales.commandKey`): по нему
  /// видно, чья это попытка, когда в базе остались следы двух.
  TextColumn get commandKey => text().nullable()();

  /// Документ-основание: номер сертификата, номер предоплаты, договор
  /// рассрочки.
  ///
  /// Предоплате отдельной таблицы и отдельного остатка не заводится
  /// (спека, ярус 6): строка `Payments` с видом `prepayment` и документом
  /// здесь — это всё, что нужно.
  TextColumn get reference => text().nullable()();

  /// Код внешнего провайдера у видов, которые с ним разговаривают
  /// (QR/СБП). Без него подтверждение, пришедшее снаружи, не с чем
  /// сверить.
  TextColumn get providerCode => text().nullable()();

  /// # Ключ по чеку — больше **не** последняя линия против двойного взятия
  ///
  /// До задачи 8 он ею был, и это замер, а не толкование: условная запись
  /// «занять чек» переводила состояние никак, второй гонщик проходил её
  /// условие целиком, и разводил двоих именно
  /// `{receiptNo, posId, payeeAccountId}` — сырым `SqliteException(2067)`
  /// уже **после** того, как первый взял деньги. Роль эта была ненадёжной:
  /// стоило гонщикам попасть на разные счета получателя (наличные на счёт
  /// кассы, карта на банковский), и ключ молчал — с чека на 1000
  /// собиралось 2000 (`test/data/sale/payment_claim_race_test.dart`).
  ///
  /// Задача 8 поставила настоящий заслон впереди:
  /// `LocalPaymentService._stateClaimedForPayment`. Ключ остаётся как
  /// страховка второго ряда, а не как единственная.
  ///
  /// # Оговорка тому, кто соберётся менять ключ — **исполнена задачей 14,
  /// и оставлена здесь целиком, потому что сторожить надо и дальше**
  ///
  /// Замена на `{receiptNo, posId, seq}` защищает так же, **только пока
  /// `seq` считается от нуля на каждой попытке оплаты.** Подготовка чека
  /// снимает платежи прошлой попытки (`paymentDao.deleteBySale`), и тогда
  /// оба гонщика получают 0, 1, 2… и сталкиваются. `seq`, продолжающий
  /// нумерацию прошлой попытки («максимум + 1»), превращает ключ в
  /// украшение: гонщики получат разные номера и не столкнутся никогда, а
  /// узнать об этом будет неоткуда — набор останется зелёным.
  ///
  /// Сегодня `seq` считается **от нуля** и не читает базу вовсе:
  /// `SaleUseCaseImpl.perform` нумерует список платежей, пришедший от
  /// `LocalPaymentService` (`payments.indexed`). Ни одного `MAX(seq) + 1`
  /// в дереве нет, и это сторожится
  /// `test/data/sale/payment_seq_from_zero_test.dart`.
  ///
  /// # Зачем ключ менялся
  ///
  /// Старый ключ `{receiptNo, posId, payeeAccountId}` запрещал **две
  /// законные строки на один счёт**: наличную и безналичную часть, обе
  /// упавшие на счёт кассы, и — с задачи 14 — две строки разных видов на
  /// одном счёте вообще. Ради него существовал отдельный отказ
  /// `payment_account_conflict`, снятый той же задачей. Ключ по `seq`
  /// защищает от гонки, ничего законного не запрещая.
  @override
  List<Set<Column>> get uniqueKeys => [
    {receiptNo, posId, seq},
    {refundLocalId, seq},
  ];
}
