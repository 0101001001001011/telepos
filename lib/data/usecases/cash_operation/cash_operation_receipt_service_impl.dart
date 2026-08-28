import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/print/print_submission.dart';
import 'package:telepos/domain/entities/cash_operation/cash_operation_receipt_data.dart';
import 'package:telepos/domain/print/print_document_id.dart';
import 'package:telepos/domain/print/print_queue.dart';
import 'package:telepos/domain/usecases/cash_operation/cash_in_out_controller.dart';
import 'package:telepos/domain/usecases/cash_operation/cash_operation_receipt_service.dart';
import 'package:telepos/hardware/printer/receipt/cash_operation_receipt_builder.dart';

/// Собирает квитанцию кассовой операции и **сдаёт её в очередь печати**.
///
/// ## Что здесь изменилось и почему
///
/// До этой правки метод писал готовые байты прямо в `PrinterManager.writeRaw`,
/// и это было два отдельных дефекта сразу.
///
/// **Второй писатель в один принтер.** Вся неделимость задания держится на том,
/// что писатель один (`PrintQueueLocal._running`). Запись мимо очереди — это
/// второй писатель, то есть квитанция внесения, вклинившаяся между строками
/// чека покупателя. Отказ назван архитектурой прямо
/// (docs/system-architecture.md, раздел 8, И29), и пара «кассовая операция во
/// время смены» — не редкость, а именно тот момент, когда в очереди стоят чеки.
///
/// **Единственная квитанция, которая ещё терялась.** Неудача возвращалась как
/// `false` и исчезала вместе с локальными переменными: деньги записаны, бумаги
/// нет, повторить нечего. Всё остальное к этому моменту уже переживало
/// недоступный принтер заданием в базе; это — нет.
///
/// Прямого пути к принтеру отсюда больше не существует: `PrinterManager` в этом
/// файле не упоминается вовсе.
class CashOperationReceiptServiceImpl implements CashOperationReceiptService {
  CashOperationReceiptServiceImpl({
    required AppDatabase db,
    required Talker logger,
  }) : _db = db,
       _logger = logger,
       _submission = PrintSubmission(logger: logger);

  final AppDatabase _db;
  final Talker _logger;
  final PrintSubmission _submission;

  @override
  Future<CashOperationReceiptData?> buildReceiptData(int operationId) async {
    try {
      // Прямо по ключу. Раньше здесь стоял `findByState(1)` со сравнением
      // идентификаторов в памяти: операция, чьё состояние однажды перестанет
      // быть единицей, молча перестала бы печататься, и разницу между «нет
      // такой операции» и «состояние другое» никто бы не увидел.
      final operation = await _db.cashOperationDao.findById(operationId);

      if (operation == null) {
        _logger.warning('CashOperation not found: $operationId');
        return null;
      }

      final thisPos = await _db.thisPosDao.get();
      final companyName = thisPos?.companyName ?? 'TelePOS';
      final currencySymbol = thisPos?.currencySymbol ?? '₸';

      String? cashierName;
      if (operation.userId != null) {
        final user = await _db.userDao.findById(operation.userId!);
        cashierName = user?.name;
      }

      return CashOperationReceiptDataBuilder()
          .setCompanyName(companyName)
          .setReceiptNumber(operation.id)
          .setType(CashInOutTypeExtension.fromIndex(operation.type))
          .setDocTime(
            DateTime.fromMillisecondsSinceEpoch(
              (operation.docTime ?? 0) * 1000,
            ),
          )
          .setCashierName(cashierName)
          .setAmount(operation.amount)
          .setCurrencySymbol(currencySymbol)
          .setNote(operation.note)
          .build();
    } catch (e, st) {
      _logger.error('Error building receipt data', e, st);
      return null;
    }
  }

  /// Сдаёт квитанцию в очередь. **Возвращается сразу и никогда не бросает**
  /// (И30): к моменту вызова деньги уже записаны, и ни отсутствие принтера, ни
  /// отказ базы не имеют права этого отменить.
  ///
  /// Идентификатор задания — чистая функция того, чем документ **является**:
  /// касса, терминал, смена, вид `cashOperation` и `CashOperations.id`. Часов
  /// в нём нет ни одной части, поэтому повтор той же квитанции — хоть после
  /// перезапуска программы — узнаётся очередью как повтор и второй бумаги не
  /// печатает.
  @override
  Future<PrintSubmitOutcome> printReceipt(int operationId) async {
    const kind = PrintDocumentKind.cashOperation;
    try {
      final receiptData = await buildReceiptData(operationId);
      if (receiptData == null) {
        return PrintSubmitOutcome.rejected(
          PrintSubmission.unidentifiedJobId(kind),
          'Кассовая операция $operationId не найдена — печатать нечего',
        );
      }

      final documentId = await _submission.identify(
        kind: kind,
        // Номер квитанции — `CashOperations.id`, то есть ключ строки, под
        // которой движение денег записано в базе. Он долговечен: та же
        // операция через год и в другом процессе даст ту же строку
        // идентификатора. Момент сюда не годится — квитанция №42 остаётся
        // квитанцией №42, сколько бы раз её ни печатали.
        number: '$operationId',
        copyIndex: 0,
      );

      final paperWidth = (await _db.thisPosDao.get())?.paperWidth ?? 48;
      final bytes = CashOperationReceiptBuilder(
        data: receiptData,
        paperWidth: paperWidth,
      ).build();

      return await _submission.submit(bytes, documentId);
    } catch (e) {
      return _submission.cannotIdentify(kind, e);
    }
  }
}
