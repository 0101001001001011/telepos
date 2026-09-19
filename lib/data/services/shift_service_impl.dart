import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:get_it/get_it.dart';
import 'package:talker/talker.dart';
// `hide FiscalQueueEntry`: одноимённая строка есть и у drift-таблицы
// очереди, и у самой очереди (`offline_queueing_provider.dart`). Здесь
// нужна вторая — та, у которой есть `payload` и `writeOff`.
import 'package:telepos/data/database/app_database.dart' hide FiscalQueueEntry;
import 'package:telepos/data/fiscal/fiscal_replay_scheduler.dart';
import 'package:telepos/data/fiscal/offline_queueing_provider.dart';
import 'package:telepos/data/shift/shift_age_rule.dart';
import 'package:telepos/domain/services/shift_service.dart';
import 'package:telepos/domain/usecases/fiscal/fiscal_service.dart';

/// Сколько закрытие смены ждёт досылку документов оператору, прежде чем
/// признать их ждущими.
///
/// # Почему предел вообще нужен
///
/// Проход повтора при мёртвом операторе стоит **тайм-аут клиента на
/// строку** (30 с) до трёх подряд (`maxConsecutiveTransient`), то есть до
/// полутора минут. Полторы минуты кассир смотрит на кнопку «Закрыть»,
/// которая ничего не делает, — а закрывают смену в конце дня. Ждать столько
/// нельзя.
///
/// # Почему пятнадцать секунд
///
/// * живой оператор отвечает на документ за доли секунды, и пятнадцати
///   секунд хватает на десятки ждущих строк — то есть на всю обычную
///   очередь целиком;
/// * мёртвый узнаётся раньше первого же тайм-аута клиента (30 с): ждать
///   дольше половины его бессмысленно, ответа уже не будет.
///
/// Предел **не отменяет прохода**: он продолжается в фоне и довезёт всё,
/// что довезётся. Отменяется только ожидание, и тогда касса считает
/// недовезённое ждущим — то есть Z-отчёт придерживает. Ошибка в эту
/// сторону стоит задержанного отчёта; в другую — выручки одного дня в
/// отчёте другого.
const Duration kShiftCloseFlushBudget = Duration(seconds: 15);

class ShiftServiceImpl implements ShiftService {
  ShiftServiceImpl({
    required AppDatabase db,
    required Talker logger,
    Duration flushBudget = kShiftCloseFlushBudget,
  }) : _db = db,
       _logger = logger,
       _flushBudget = flushBudget;

  final AppDatabase _db;
  final Talker _logger;

  /// Предел ожидания досылки перед Z-отчётом — довод, а не константа в
  /// теле: проба не имеет права стоять пятнадцать секунд, чтобы доказать,
  /// что касса не стоит.
  final Duration _flushBudget;

  @override
  Future<void> onOpenShift(int userId, {Decimal? openingCash}) async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final float = openingCash ?? Decimal.zero;

    await _db
        .into(_db.shifts)
        .insert(
          ShiftsCompanion.insert(
            userId: userId,
            openTime: now,
            isOpened: true,
            isSynced: false,
            openingCash: Value(float),
          ),
        );

    _logger.info(
      'ShiftService: shift opened for user $userId, '
      'openingCash: $float',
    );

    // Порядок выбран, а не случаен: долг гасится **после** записи смены
    // (иначе проход повтора отказал бы по закрытой смене) и **до** первой
    // продажи (иначе сегодняшние документы попали бы во вчерашний отчёт).
    // Разбор целиком — [settleOwedZReport].
    await settleOwedZReport();

    await _fiscalOpenShift();
  }

  /// Догасить **задержанный Z-отчёт** — при открытии смены и только тут.
  ///
  /// # Что было измерено (ревизия 2026-09-19, беда 2)
  ///
  /// Закрытие смены не отправляет Z, пока документы смены не у оператора,
  /// — и это верно (разбор в [_fiscalCloseShift]). Хвост: **досылать
  /// задержанный Z было некому**. Хранилища «Z должен» не существовало, и
  /// отчёт посылало только следующее закрытие смены. У заказчика это
  /// выглядело так: смена оператора остаётся открытой, и старше суток она
  /// отвечает кодом 12 на первой продаже следующего дня — касса утром не
  /// продаёт.
  ///
  /// # Почему именно открытие смены, а не круг повтора
  ///
  /// Рассматривались три двери, и выбрана одна.
  ///
  /// * **Круг повтора `FiscalReplayScheduler`** — самая естественная на
  ///   вид и негодная по сути. Он ходит днём, и к его проходу
  ///   **сегодняшние** документы уже у оператора: они уезжают напрямую,
  ///   минуя очередь. Z, посланный в полдень, закрыл бы смену оператора
  ///   вместе с утренней выручкой — то есть завёл бы ровно ту беду, ради
  ///   которой отчёт и придерживают.
  /// * **Кнопка на экране диагностики** — не решение, а перекладывание:
  ///   беда в том, что задержку **никто не замечает**, и кнопка ждала бы
  ///   человека, который о ней знает. (Долг при этом читается —
  ///   [owedZReport], — и кнопку по нему сделать можно; она будет вторым
  ///   входом, а не первым.)
  /// * **Открытие смены** — единственный момент, когда выполняется
  ///   условие «ни одного своего документа у оператора ещё нет»: смена
  ///   кассы только что записана, продаж в ней ноль. Всё, что у оператора
  ///   в открытой смене, относится к вчерашнему дню — и ровно это Z
  ///   обязан закрыть.
  ///
  /// # Порядок внутри
  ///
  /// Один проход повтора (тем же пределом ожидания, что при закрытии) —
  /// он довозит вчерашние документы; затем очередь спрашивается заново, и
  /// Z уходит **только** на пустой. Не опустела — долг остаётся висеть с
  /// названной причиной и сосчитанной попыткой, а смена кассы открывается
  /// как ни в чём не бывало: запирать кассу из-за вчерашнего отчёта
  /// нельзя.
  ///
  /// # Чего это НЕ доказывает
  ///
  /// Что код 12 больше не случится. Он случится, если оператор недоступен
  /// и утром: вчерашние документы не доедут, Z не уйдёт, смена оператора
  /// останется открытой. Чинится здесь другое — **касса перестала терять
  /// отчёт молча и навсегда**; теперь долг записан, переживает
  /// перезапуск, гасится сам при первой возможности и виден.
  @override
  Future<void> settleOwedZReport() async {
    final FiscalOwedReport owed;
    try {
      final row = await _db.fiscalOwedReportDao.current();
      if (row == null) return;
      owed = row;
    } catch (e, st) {
      _logger.warning('ShiftService: долг по Z не читается: $e', e, st);
      return;
    }

    _logger.info(
      'ShiftService: висит задержанный Z за смену ${owed.shiftId} '
      '(с ${DateTime.fromMillisecondsSinceEpoch(owed.owedAt * 1000)}, '
      'попыток ${owed.attempts}) — досылаем до первой продажи',
    );

    final stillWaiting = await _flushFiscalQueue();
    if (stillWaiting > 0) {
      await _noteOwedAttempt(
        owed.id,
        'документы вчерашней смены не доехали: $stillWaiting',
      );
      _logger.error(
        'ShiftService: задержанный Z за смену ${owed.shiftId} НЕ отправлен — '
        '$stillWaiting документ(ов) всё ещё не у оператора. Смена оператора '
        'остаётся открытой; после 24 часов она ответит кодом 12 на продаже.',
      );
      return;
    }

    final sent = await _sendZReport(
      why: 'досылка за смену ${owed.shiftId}',
      settledBy: 'досылка при открытии смены',
    );
    if (!sent) {
      await _noteOwedAttempt(owed.id, 'оператор не принял отчёт');
    }
  }

  Future<void> _noteOwedAttempt(int id, String reason) async {
    try {
      await _db.fiscalOwedReportDao.noteAttempt(id: id, reason: reason);
    } catch (e, st) {
      _logger.warning('ShiftService: попытка по долгу Z не записана: $e', e, st);
    }
  }

  @override
  Future<OwedZReport?> owedZReport() async {
    try {
      final row = await _db.fiscalOwedReportDao.current();
      if (row == null) return null;
      return OwedZReport(
        shiftId: row.shiftId,
        owedAt: DateTime.fromMillisecondsSinceEpoch(row.owedAt * 1000),
        documentsWaiting: row.documentsWaiting,
        attempts: row.attempts,
        lastError: row.lastError,
      );
    } catch (e, st) {
      _logger.warning('ShiftService: долг по Z не читается: $e', e, st);
      return null;
    }
  }

  /// Закрытие смены: **сначала документы, потом отчёт о них**.
  ///
  /// # Что было измерено (ревизия 2026-09-19)
  ///
  /// `_fiscalCloseShift` звал `fiscal.closeShift()` сразу, не оглядываясь на
  /// `FiscalReplayScheduler`. Круг повтора — две минуты
  /// (`kFiscalReplayInterval`), и чек, легший в очередь в последние минуты
  /// смены, уезжал к оператору **после** Z-отчёта: в отчёте его нет, а в
  /// кассе он есть. Хуже того, документ попадал уже в следующую смену
  /// оператора (WebKassa открывает смену неявно, первым документом), то есть
  /// выручка вчерашнего дня оказывалась в сегодняшнем отчёте. Никакой
  /// проверки на это нет ни у кассы, ни у оператора — расхождение молчит.
  ///
  /// # Почему проход ждём **здесь**, до записи закрытия
  ///
  /// `FiscalReplayScheduler.runOnce` не делает прохода при закрытой смене
  /// кассы — и правильно, разбор в его докстринге («не открыть смену
  /// оператора неявно ночью»). Позови мы его после `isOpened = false`, он
  /// молча отложил бы проход до утра, а Z ушёл бы первым. Поэтому проход
  /// стоит **до** записи: смена кассы ещё открыта, смена оператора ещё
  /// открыта, и это единственный момент, когда досылка документов законна.
  ///
  /// # Почему один проход, а не «пока очередь не опустеет»
  ///
  /// Ожидание «пока пусто» при мёртвом операторе не кончится никогда, и
  /// касса встала бы посреди закрытия смены — с деньгами в ящике и кассиром,
  /// которому пора домой. Проход один: связь есть — он увезёт всё, что
  /// увезётся (`replay` идёт по всей очереди, а не по одной строке); связи
  /// нет — он вернётся быстро, по тайм-ауту клиента.
  ///
  /// Проход, который **уже идёт**, этим вызовом не обрывается и не
  /// дублируется: замок `OfflineQueueingProvider.replay` поставит наш
  /// следующим, и мы дождёмся именно его.
  ///
  /// # Чего это НЕ доказывает
  ///
  /// Что после закрытия все документы смены у оператора. Доказывается
  /// только одно: Z-отчёт **не уходит раньше** документов — либо они уехали,
  /// либо отчёта нет (см. [_fiscalCloseShift]). Смену кассы это не запирает
  /// никогда.
  @override
  Future<void> onCloseShift(Decimal cashInPos) async {
    final currentShift = await _db.shiftDao.findOpenedShift();
    if (currentShift == null) {
      _logger.warning('ShiftService: no opened shift to close');
      return;
    }

    final documentsWaiting = await _flushFiscalQueue();

    final closeTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final preciseOpenTime = await _getPreciseShiftOpenTime(currentShift);

    await (_db.update(
      _db.shifts,
    )..where((sh) => sh.id.equals(currentShift.id))).write(
      ShiftsCompanion(
        openTime: Value(preciseOpenTime),
        isOpened: const Value(false),
        closeTime: Value(closeTime),
        cashInPosOnShiftClose: Value(cashInPos),
      ),
    );

    _logger.info(
      'ShiftService: shift ${currentShift.id} closed, '
      'cash: $cashInPos, openTime adjusted: ${preciseOpenTime != currentShift.openTime}',
    );

    try {
      await _db.checkpointWal();
    } catch (e, st) {
      _logger.warning(
        'ShiftService: WAL checkpoint after close failed: $e',
        e,
        st,
      );
    }

    // Названо **до** Z-отчёта: если оператор недоступен и здесь, отчёт
    // уйдёт в свой `catch`, а число нефискализованных чеков в журнале
    // останется. Порядок выбран, а не случаен.
    await _nameUnfiscalized(currentShift.id);

    await _fiscalCloseShift(
      documentsWaiting: documentsWaiting,
      shiftId: currentShift.id,
    );
  }

  /// Один проход повтора — и сколько документов после него **всё ещё не у
  /// оператора**.
  ///
  /// Число читается из очереди, а не из отчёта прохода: прохода могло не
  /// быть вовсе (планировщик не собран, провайдер не очередной, очередь
  /// пуста), и «отчёта нет» не то же самое, что «везти нечего».
  ///
  /// Очередь, которую **не прочесть** (бросок хранилища), считается
  /// пустой — и это выбор со своей ценой. Признать её непустой значило бы
  /// запереть Z-отчёт навсегда на сломанном хранилище: отчёт не ушёл бы ни
  /// сегодня, ни завтра, и смена оператора не закрывалась бы никогда.
  /// Обратная цена названа вслух: на нечитаемой очереди касса теряет ровно
  /// ту защиту, ради которой этот метод написан, и говорит об этом в
  /// журнале.
  Future<int> _flushFiscalQueue() async {
    try {
      if (GetIt.I.isRegistered<FiscalReplayScheduler>()) {
        final report = await GetIt.I<FiscalReplayScheduler>()
            .runOnce('закрытие смены')
            // Ожидание ограничено ([kShiftCloseFlushBudget]); сам проход
            // продолжается в фоне. Недождавшееся считается ждущим, и
            // Z-отчёт придерживается — ошибка в эту сторону дешевле.
            .timeout(
              _flushBudget,
              onTimeout: () {
                _logger.warning(
                  'ShiftService: досылка документов не уложилась в '
                  '${_flushBudget.inSeconds} с — проход продолжается в фоне, '
                  'Z-отчёт решается по очереди на эту секунду',
                );
                return null;
              },
            );
        if (report != null) {
          _logger.info(
            'ShiftService: перед Z-отчётом проход очереди — '
            'fiscalized=${report.fiscalized} duplicates=${report.duplicates} '
            'failed=${report.failed} remaining=${report.remaining}',
          );
        }
      }
    } catch (e, st) {
      _logger.warning(
        'ShiftService: проход очереди перед Z не удался: $e',
        e,
        st,
      );
    }
    try {
      if (!GetIt.I.isRegistered<FiscalQueueStore>()) return 0;
      return await GetIt.I<FiscalQueueStore>().pendingCount();
    } catch (e, st) {
      _logger.warning(
        'ShiftService: очередь фискализации не читается — Z-отчёт уйдёт без '
        'этой проверки: $e',
        e,
        st,
      );
      return 0;
    }
  }

  @override
  Future<UnfiscalizedAtClose> unfiscalizedAtClose() async {
    try {
      if (!GetIt.I.isRegistered<FiscalQueueStore>()) {
        return UnfiscalizedAtClose.empty;
      }
      final store = GetIt.I<FiscalQueueStore>();
      final failed = (await store.failed())
          .where((e) => e.writeOff == null)
          .toList();
      // Ждущие строки — вторая половина сводки: беды в них ещё нет, но
      // Z-отчёт, ушедший раньше них, разойдётся с кассой, и кассиру это
      // говорится **до** нажатия «Закрыть», а не задним числом в журнале.
      final onTheWay = await store.pending();
      return UnfiscalizedAtClose(
        count: failed.length,
        receiptNumbers: _receiptNumbers(failed),
        onTheWay: onTheWay.length,
        onTheWayReceipts: _receiptNumbers(onTheWay),
      );
    } catch (e, st) {
      _logger.warning('ShiftService: unfiscalizedAtClose error: $e', e, st);
      return UnfiscalizedAtClose.empty;
    }
  }

  /// Номера чеков строк очереди. Список **короче** списка строк, когда
  /// номер не читается: у строк старого вида он лежит в записке
  /// (`receiptNo`), у документа — в `localOperationId`, а у строки, легшей
  /// до задачи 11, может не быть вовсе. Выдумывать его здесь нечем.
  List<int> _receiptNumbers(List<FiscalQueueEntry> rows) {
    final numbers = <int>[];
    for (final row in rows) {
      final fromDocument = row.payload['localOperationId'];
      final fromNote = row.payload['receiptNo'];
      final n = fromDocument is int
          ? fromDocument
          : (fromNote is int ? fromNote : null);
      if (n != null) numbers.add(n);
    }
    return numbers;
  }

  Future<void> _nameUnfiscalized(int shiftId) async {
    final summary = await unfiscalizedAtClose();
    // Именно `hasFailed`, а не `isEmpty`: ждущие строки — не беда этого
    // сообщения, у них своя дорога (Z-отчёт их дожидается). Предупреждение
    // на пустом месте обесценивает предупреждение.
    if (!summary.hasFailed) return;
    _logger.error(
      'ShiftService: смена $shiftId закрыта с нефискализованными чеками — '
      '${summary.count} шт., номера: '
      '${summary.receiptNumbers.isEmpty ? 'не читаются' : summary.receiptNumbers.join(', ')}. '
      'Деньги по ним взяты, документа нет; разбор — экран '
      'нефискализованных чеков.',
    );
  }

  /// Z-отчёт — **только после документов своей смены**.
  ///
  /// # Отказ с названной причиной, и у отказа есть выход
  ///
  /// [documentsWaiting] больше нуля — значит проход
  /// ([ShiftServiceImpl.onCloseShift]) не смог увезти всё: оператор
  /// недоступен или отвечает транзиентными отказами. Тогда Z **не
  /// отправляется**, и это выбор из двух зол, а не осторожность:
  ///
  /// * отправить — ждущие документы приедут уже в следующую смену
  ///   оператора, и выручка одного дня встанет в отчёт другого. Касса при
  ///   этом промолчит: проверить это нечем ни у неё, ни у оператора. Ровно
  ///   эта дыра и чинится;
  /// * не отправлять — смена оператора остаётся открытой, ждущие документы
  ///   приедут **в неё же** (в ту, к которой относятся), а закроет её
  ///   следующий Z. Деньги ни одного дня не переезжают в чужой отчёт;
  ///   расхождение видно, названо и разбираемо.
  ///
  /// Второе хуже выглядит и лучше считается — выбрано оно.
  ///
  /// # Почему это не запирает кассу
  ///
  /// Смена кассы закрывается **всегда** — запись уже сделана к моменту
  /// этого вызова. Кассир уходит домой, деньги посчитаны, расхождение
  /// записано. Не уходит только отчёт оператору, и «не ушёл» здесь
  /// временно по построению: строки очереди живут автономным окном 72 ч
  /// (`kOfflineFiscalWindow`), после которого проход сам переводит их в
  /// `failed`, и следующий Z уходит без всяких условий. То есть у отказа
  /// есть выход, и он наступает сам, без человека.
  ///
  /// # Задержанный отчёт теперь записывается как долг
  ///
  /// Правка 2026-09-19 (беда 2): «не отправлен» перестало означать
  /// «забыт». Долг ложится в `FiscalOwedReports`, переживает перезапуск
  /// кассы и гасится при следующем открытии смены — до первой продажи
  /// нового дня. Разбор, почему именно там, — [settleOwedZReport].
  ///
  /// # Чего это НЕ доказывает
  ///
  /// Что Z уйдёт завтра. Если оператор недоступен и утром, долг останется
  /// висеть, а смена оператора старше суток ответит кодом 12 на первой
  /// продаже. Доказывается другое: отчёт больше не теряется молча —
  /// причина названа, долг записан, попытка будет.
  Future<void> _fiscalCloseShift({
    required int documentsWaiting,
    required int shiftId,
  }) async {
    if (documentsWaiting > 0) {
      await _oweZReport(shiftId: shiftId, documentsWaiting: documentsWaiting);
      _logger.error(
        'ShiftService: Z-отчёт оператору НЕ отправлен — $documentsWaiting '
        'документ(ов) этой смены ещё не у оператора. Отчёт, ушедший раньше '
        'них, поставил бы их в следующую смену оператора, и его отчёт '
        'разошёлся бы с кассой. Смена кассы закрыта; документы уедут '
        'повтором, отчёт записан долгом и уйдёт при открытии следующей '
        'смены — до первой продажи.',
      );
      return;
    }
    // Погашение — **на успехе отправки**, а не здесь: Z этой смены
    // закрывает смену оператора целиком, вместе со всем, что в ней
    // висело. Разбор — `FiscalOwedReportDao.settleAll`.
    await _sendZReport(
      why: 'закрытие смены $shiftId',
      settledBy: 'отчёт закрытия смены $shiftId',
    );
  }

  Future<void> _oweZReport({
    required int shiftId,
    required int documentsWaiting,
  }) async {
    try {
      await _db.fiscalOwedReportDao.owe(
        shiftId: shiftId,
        at: DateTime.now(),
        documentsWaiting: documentsWaiting,
      );
    } catch (e, st) {
      // Долг не записался — это хуже, чем незаписанная попытка, и потому
      // назван ошибкой, а не предупреждением: касса вернулась к прежнему
      // поведению «Z пошлёт следующее закрытие».
      _logger.error('ShiftService: долг по Z не записан: $e', e, st);
    }
  }

  /// Отправить Z и, если он ушёл, погасить долг. `true` — отчёт у
  /// оператора.
  ///
  /// «Фискализация выключена» и «служба не собрана» считаются **не
  /// отправкой**, но и не отказом: долга в этих сборках не бывает, гасить
  /// нечего.
  Future<bool> _sendZReport({
    required String why,
    required String settledBy,
  }) async {
    try {
      if (!GetIt.I.isRegistered<FiscalService>()) return false;
      final fiscal = GetIt.I<FiscalService>();
      if (!await fiscal.isEnabled()) return false;
      final report = await fiscal.closeShift();
      if (report.success) {
        _logger.info(
          'ShiftService: fiscal Z-report '
          '${report.result.queued ? 'queued' : 'ok'} '
          '(shift=${report.shiftNumber}, $why)',
        );
        await _settleOwed(settledBy);
        return true;
      }
      _logger.warning(
        'ShiftService: fiscal Z-report failed ($why): '
        '${report.result.errorMessage}',
      );
      return false;
    } catch (e, st) {
      _logger.warning('ShiftService: fiscal Z-report error ($why): $e', e, st);
      return false;
    }
  }

  Future<void> _settleOwed(String by) async {
    try {
      final closed = await _db.fiscalOwedReportDao.settleAll(
        at: DateTime.now(),
        by: by,
      );
      if (closed > 0) {
        _logger.info(
          'ShiftService: задержанных Z-отчётов погашено: $closed ($by)',
        );
      }
    } catch (e, st) {
      _logger.warning('ShiftService: долг по Z не погашен: $e', e, st);
    }
  }

  Future<void> _fiscalOpenShift() async {
    try {
      if (!GetIt.I.isRegistered<FiscalService>()) return;
      final fiscal = GetIt.I<FiscalService>();
      if (!await fiscal.isEnabled()) return;
      await fiscal.openShift();
    } catch (e, st) {
      _logger.warning('ShiftService: fiscal openShift error: $e', e, st);
    }
  }

  @override
  Future<Shift?> getOpenedShift() async {
    return _db.shiftDao.findOpenedShift();
  }

  /// Та же мера, что у кассы (`ShiftAgeRule`), — одна арифметика на всё
  /// приложение (задача 27). Ошибка чтения больше не превращается в «не
  /// старше»: прежний `catch` → `false` был той же молчаливой деградацией,
  /// что и пропущенный порт (задача 41).
  @override
  Future<bool> isShiftOverAge({Duration maxAge = const Duration(hours: 24)}) =>
      ShiftAgeRule(db: _db, maxAge: maxAge).isOverAge();

  Future<int> _getPreciseShiftOpenTime(Shift currentShift) async {
    if (!currentShift.isOpened) {
      throw StateError('Current Shift is already closed');
    }

    final shiftOpenTime = currentShift.openTime;

    final lastShiftReport = await _db.shiftDao.findLastClosedShiftReport();
    if (lastShiftReport == null) {
      return shiftOpenTime;
    }

    final lastCloseTime = lastShiftReport.closeTime;
    if (lastCloseTime == null) {
      return shiftOpenTime;
    }

    final firstSale = await _db.saleDao.findFirstSaleAfter(lastCloseTime);
    if (firstSale == null) {
      return shiftOpenTime;
    }

    final saleTime = firstSale.time;

    if (shiftOpenTime > saleTime) {
      _logger.info(
        'ShiftService: adjusting openTime from $shiftOpenTime to $saleTime '
        '(first sale is earlier)',
      );
      return saleTime;
    }

    return shiftOpenTime;
  }
}
