import 'package:drift/drift.dart';
import 'package:telepos/data/database/converters/decimal_converter.dart';

class CashOperations extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get storeId => integer().nullable()();

  RealColumn get amount => real().map(const DecimalConverter())();

  IntColumn get accountId => integer().nullable()();

  IntColumn get type => integer()();

  IntColumn get userId => integer().nullable()();

  TextColumn get note => text().nullable()();

  IntColumn get docTime => integer().nullable()();

  IntColumn get state => integer().nullable()();

  /// Вид оплаты, **которым приняты деньги** (v47): наличные, карта, QR.
  ///
  /// До v47 не хранился, и аванс, принятый картой, уезжал оператору
  /// наличными. `null` у строк старше v47 — «не записано», а не «наличные».
  IntColumn get kindId => integer().nullable()();

  /// Основание операции числом (v58).
  ///
  /// # Зачем столбец, когда есть примечание
  ///
  /// До v58 род жил ВНУТРИ примечания: касса писала туда
  /// `'Зарплата: комментарий кассира'`. Два следствия, оба дефекта.
  ///
  /// * **Перевести нельзя.** Слово записано в историю, и на английской
  ///   кассе подпись под операцией оставалась русской. Ключи словаря
  ///   (`cashSalary`, `cashUtilities`, …) при этом существовали во всех
  ///   пяти языках и не спрашивались нигде.
  /// * **Просуммировать нельзя.** «Сколько ушло на зарплату за месяц» —
  ///   законный вопрос к кассе, и ответить на него значило разбирать
  ///   русскую прозу по двоеточию.
  ///
  /// Типизованное поле, смазанное в текст, — это потерянное поле. Теперь
  /// основание хранится числом, примечание несёт ТОЛЬКО то, что напечатал
  /// человек, а слово выбирается при показе на языке интерфейса.
  ///
  /// # Почему «основание», а не «род расхода»
  ///
  /// Прозу в примечание писал не только расход. Погашение рассрочки и
  /// пополнение счёта покупателя — операции ВНЕСЕНИЯ, и туда уезжали
  /// «Погашение рассрочки №12» и «Вложение на счёт покупателя». Столбец с
  /// именем `expenseKind` пришлось бы либо обходить, либо толковать
  /// вопреки имени.
  ///
  /// Пространство кодов одно и описано в `domain/cash/cash_operation_kind
  /// .dart`: 0–5 — роды расхода (ровно `ExpenseType.index`, чтобы не
  /// заводить второе перечисление для того же понятия), от 100 — основания,
  /// которые ставит сама касса.
  ///
  /// `null` у строк старше v58 — «не записано», а не «прочее»: у них
  /// основание осталось в примечании, и притворяться, будто оно известно,
  /// нельзя.
  IntColumn get reasonCode => integer().nullable()();
}

class CashOperationCustomFields extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get cashOperationId => integer().nullable()();

  IntColumn get customFieldId => integer().nullable()();

  IntColumn get customFieldItemId => integer().nullable()();
}
