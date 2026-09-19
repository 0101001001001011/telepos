import 'package:drift/drift.dart';

/// Подарочные сертификаты — задача 21, схема v42.
///
/// Зачем таблица вообще нужна и почему деньги здесь целыми тысячными —
/// в докстринге `lib/domain/payment/gift_certificate.dart`. Здесь только
/// то, что относится к самой форме хранения.
///
/// # Удаления нет
///
/// `Payments.reference` ссылается на [number] навсегда: чек трёхлетней
/// давности обязан объяснять, чем его оплатили. Отзыв — это
/// `CertificateStatus.cancelled`, а не `DELETE`. Метода `delete` нет ни у
/// DAO, ни у контракта — тот же довод, что у `PaymentKinds`.
///
/// # Ключ по номеру, а не по ид
///
/// Уникальность [number] — не украшение справочника, а **вторая линия
/// заслона от двойного выпуска**: касса проверяет `byNumber` перед
/// вставкой, но между проверкой и вставкой есть окно, и закрывает его
/// только ключ. Первая линия объясняет кассиру, вторая не даёт беде
/// случиться.
@DataClassName('GiftCertificateRow')
class GiftCertificates extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Номер, напечатанный на бумажке.
  TextColumn get number => text().withLength(min: 1, max: 64)();

  /// ПИН **хэшем** (`PinCredential`), а не текстом. Разбор — в докстринге
  /// `GiftCertificate.pinHash`.
  TextColumn get pinHash => text().nullable()();

  /// Номинал, **целыми тысячными**. Не меняется никогда.
  IntColumn get nominalMillis => integer()();

  /// Остаток, **целыми тысячными**.
  ///
  /// Уменьшается условной записью `CertificateDao.redeem` и только ею.
  /// Никакого `updateBalance(вычислено снаружи)`: между чтением и записью
  /// открывается ровно то окно, ради которого условная запись и заведена.
  IntColumn get balanceMillis => integer()();

  /// `CertificateStatus` **стабильным кодом-строкой**, а не индексом члена.
  TextColumn get status => text().withLength(min: 1, max: 16)();

  /// Секунды эпохи — тем же масштабом, что `payments.time`.
  IntColumn get issuedAt => integer()();

  /// Когда истекает. `null` — бессрочный.
  IntColumn get expiresAt => integer().nullable()();

  /// Чек выпуска. `null` у сертификатов, заведённых не продажей
  /// (перенос тиража, подарок от сети): выдумывать им чек нельзя.
  IntColumn get issuedReceiptNo => integer().nullable()();

  IntColumn get issuedPosId => integer().nullable()();

  IntColumn get issuedByUserId => integer().nullable()();

  /// Счёт обязательства кассы, на который лёг номинал при выпуске.
  ///
  /// Хранится у сертификата, а не выводится из справочника видов: счёт
  /// оператор вправе сменить, а обязательство, взятое год назад, лежит на
  /// том счёте, на который его тогда положили.
  IntColumn get liabilityAccountId => integer().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {number},
  ];
}
