import 'package:telepos/core/errors/safe_error_text.dart';
import 'dart:typed_data';

import 'package:get_it/get_it.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/print/print_document_id.dart';
import 'package:telepos/domain/print/print_job.dart';
import 'package:telepos/domain/print/print_queue.dart';
import 'package:telepos/domain/terminal/terminal_repository.dart';

/// **Шов между документом и транспортом: единственная дорога байтов в очередь.**
///
/// Выше этого класса — логика документа (что напечатано, из чего собрано, каким
/// шрифтом); ниже — задание печати. Байты, попавшие сюда, уже собраны целиком:
/// время проставлено, фискальные реквизиты внутри
/// (docs/system-architecture.md, раздел 8: «принтер получает уже полностью
/// сформированные данные»).
///
/// **Почему это отдельный класс, а не метод в службе чеков.** Служб, печатающих
/// документы, две — чеки продажи (`ReceiptPrintServiceImpl`) и квитанции
/// кассовых операций (`CashOperationReceiptServiceImpl`), — а правило
/// построения идентификатора и правило сдачи в очередь у них обязаны быть
/// одним. Скопированное правило расходится молча: вторая копия, построившая
/// идентификатор чуть иначе, дала бы задания, которые очередь не узнаёт в
/// повторе, и это выглядело бы работающим до первого потерянного
/// подтверждения. Поэтому копии нет — есть один класс с двумя вызывающими.
class PrintSubmission {
  PrintSubmission({Talker? logger}) : _logger = logger;

  final Talker? _logger;

  /// Сколько задание печати имеет смысл: после этого срока чек уже не
  /// печатается сам, а становится видимой проблемой (И29 — «непечатаемое
  /// задание не висит вечно»).
  ///
  /// Полчаса — это столько, сколько покупатель ещё может стоять у кассы плюс
  /// время заправить бумагу или поднять упавшую сеть. Больше — и в очереди
  /// копятся чеки, которые уже никто не ждёт; меньше — и обычная замена рулона
  /// стоит потерянного чека. Кому нужен чек после этого срока, тот печатает
  /// дубликат из истории — это уже другой документ и другое решение.
  static const Duration documentLifetime = Duration(minutes: 30);

  /// Личность документа, который сейчас печатается.
  ///
  /// Владелец задания по И29 — терминал **и** касса, поэтому спрашиваются оба.
  /// Бросает, если хоть одного не выяснить: задание без владельца некому
  /// показать в очереди и некому повторить, а «ноль» вместо владельца — это
  /// заглушка, выглядящая значением. Бросок ловится вызывающим методом и
  /// становится [PrintSubmitStatus.rejected] с причиной — продажа и кассовая
  /// операция этого не замечают (И30).
  Future<PrintDocumentId> identify({
    required PrintDocumentKind kind,
    required String number,
    required int copyIndex,
    int? posIdHint,
  }) async {
    if (!GetIt.I.isRegistered<TerminalRepository>()) {
      throw StateError(
        'TerminalRepository не зарегистрирован — некому сказать, с какого '
        'терминала пришло задание печати (И29)',
      );
    }
    final terminal = await GetIt.I<TerminalRepository>().self();

    var posId = (posIdHint != null && posIdHint > 0) ? posIdHint : 0;
    int? shiftId;
    if (GetIt.I.isRegistered<AppDatabase>()) {
      final db = GetIt.I<AppDatabase>();
      // Смена, открытая **сейчас**, — см. доку `PrintDocumentId.shiftId`: это
      // то, что делает дубликат, распечатанный в другую смену, отдельным
      // документом, а не молча проглоченным повтором.
      shiftId = (await db.shiftDao.findOpenedShift())?.id;
      if (posId <= 0) posId = (await db.thisPosDao.get())?.id ?? 0;
    }

    return PrintDocumentId(
      terminalId: terminal.id,
      posId: posId,
      shiftId: shiftId,
      kind: kind,
      number: number,
      copyIndex: copyIndex,
    );
  }

  /// Сдаёт готовые байты документа в очередь — и **только в очередь**.
  ///
  /// Сроки [PrintJob] строятся здесь по `DateTime.now()`, и это не
  /// противоречит правилу «идентификатор не берётся из часов»: часы задают,
  /// когда задание создано и когда оно перестанет иметь смысл, а **кто** этот
  /// документ, сказано в [documentId], который часов не знает вовсе. Повторная
  /// сдача того же документа придёт с другим `createdAt` и тем же
  /// идентификатором — и очередь узнает в ней повтор, потому что задания
  /// сравниваются по идентификатору.
  ///
  /// **Никогда не бросает.** Отказ — это [PrintSubmitStatus.rejected] с
  /// причиной: исключение отсюда попало бы на путь, где деньги уже приняты.
  Future<PrintSubmitOutcome> submit(
    Uint8List payloadBytes,
    PrintDocumentId documentId,
  ) async {
    if (!GetIt.I.isRegistered<PrintQueue>()) {
      // Отказ, а не тихая прямая запись в принтер. Прямая запись здесь и была
      // бы тем самым вторым путём: он выглядел бы работающим ровно до первого
      // недоступного принтера, на котором документ снова потерялся бы.
      _logger?.warning(
        '[PrintSubmission] PrintQueue не зарегистрирована в DI — '
        'печатать нечем',
      );
      return PrintSubmitOutcome.rejected(
        documentId.value,
        'Очередь печати не настроена на этом терминале',
      );
    }

    final now = DateTime.now();
    final PrintJob job;
    try {
      job = PrintJob(
        id: documentId.value,
        terminalId: documentId.terminalId,
        posId: documentId.posId,
        payloadBytes: payloadBytes,
        createdAt: now,
        expiresAt: now.add(documentLifetime),
      );
    } catch (e) {
      // Пустой документ, отрицательный владелец — ошибка вызывающего, а не
      // отказ принтера. Она обязана быть названной, а не превратиться в
      // необработанное исключение на пути, где деньги уже приняты.
      _logger?.warning(
        '[PrintSubmission] Не удалось построить задание печати '
        '${documentId.value}: $e',
      );
      return PrintSubmitOutcome.rejected(
        documentId.value,
        'Не удалось поставить документ в очередь печати: ${safeErrorText(e)}',
      );
    }

    final outcome = await GetIt.I<PrintQueue>().submit(job);
    _logger?.debug(
      '[PrintSubmission] ${payloadBytes.length} байт → очередь: $outcome',
    );
    return outcome;
  }

  /// Ответ на «документ не удалось опознать».
  ///
  /// Идентификатора у такого задания нет — его как раз и не вышло построить, —
  /// поэтому в ответе стоит явная строка «неопознанный», а не правдоподобный
  /// ключ, который читатель мог бы принять за настоящий и попробовать
  /// повторить.
  PrintSubmitOutcome cannotIdentify(PrintDocumentKind kind, Object error) {
    _logger?.warning(
      '[PrintSubmission] Документ ${kind.name} не опознан: $error',
    );
    return PrintSubmitOutcome.rejected(
      unidentifiedJobId(kind),
      'Не удалось определить, кому принадлежит документ (${kind.name}): ${safeErrorText(error)}',
    );
  }

  /// Заведомо не-идентификатор: строка, которую нельзя перепутать с настоящим
  /// ключом задания (в настоящем есть терминал, касса, смена и разделители).
  static String unidentifiedJobId(PrintDocumentKind kind) =>
      'неопознанный-${kind.name}';

  /// Номер документа, пригодный для идентификатора: разделитель заменяется,
  /// пустая строка отвергается конструктором [PrintDocumentId].
  static String sanitizeNumber(String raw) =>
      raw.trim().replaceAll(PrintDocumentId.separator, '-');
}
