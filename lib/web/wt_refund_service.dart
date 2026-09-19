/// Возврат браузерного терминала — та же половина контракта, что у
/// `LocalRefundService`, только исполняет её касса.
///
/// Задача 20 плана «Продажа с браузерного терминала» (спека 2026-09-06,
/// шаг 9). Логики возврата здесь нет ни строки: черновик, деньги, сверки с
/// чеком и смена живут на кассе (`lib/data/refund/local_refund_service.dart`),
/// а этот файл только переводит вызовы контракта в шесть операций каталога
/// `RefundOps` и обратно.
///
/// # Почему `terminalId` не уезжает в теле
///
/// Каждый метод контракта принимает имя рабочего места — и **ни один не
/// кладёт его в кадр**. Так требует сам контракт (докстринг `RefundService`,
/// правило 1) и так устроена касса: `_refundTerminal`
/// (`lib/backend/till_operations.dart`) берёт место из **сеанса** и отвергает
/// кадр, в котором оно названо. Довод не стилистический: имя в теле пишет
/// тот же, кто попробовал бы им воспользоваться.
///
/// Довод в теле остаётся неиспользованным нарочно, а не по забывчивости —
/// убрать его из подписи нельзя, контракт общий с кассой, где место и есть
/// ключ черновика.
///
/// # Почему отказ переводится в `WireRefusal`
///
/// Контракт обещает вызывающему `WireRefusal` (докстринг `RefundService`,
/// «отказ — значение, исключение — транспорт»), а диспетчер отдаёт
/// `WtProtocolError`: тип из `lib/web/`, которого на кассе нет вовсе и
/// который экрану видеть нельзя — `refund_controller.dart` собирается и на
/// VM, и под браузер, а `lib/web/` в него не входит.
///
/// Перевод сплошной, включая транспортные коды (`no_session`, `bad_body`,
/// `no_answer`): код в отказе сохраняется, поэтому экран по-прежнему может
/// отличить «касса не отвечает» от «количество больше проданного» — по коду,
/// а не по подстроке.
///
/// **Кроме [SessionLost].** Он уходит наверх нетронутым: истёкший сеанс
/// лечится входом заново, и вкладка обязана уйти на экран входа, а не
/// показать отказ операции. Диспетчер уже отделил его от прочих кодов
/// (`_errorFor`, `wt_dispatcher.dart`), и второй раз это решение здесь не
/// принимается.
///
/// **И кроме `unknown_terminal`** — его [SessionLost]'ом делает уже этот
/// файл, и вот почему именно здесь.
///
/// Отказ означает «эта QUIC-сессия ещё не назвала кассе рабочее место».
/// Назвать его умеет только `terminals.resume`/`terminals.register`, а зовёт
/// их только вход (`LoginNotifier._resolveTerminalId`). То есть сама себя
/// вкладка из этого состояния не выводит: она выглядит вошедшей, каждая из
/// шести операций возврата отказывает, а экрана входа ей никто не
/// предлагает. Тупик, из которого кассир выбирается закрытием вкладки — тот
/// же класс дефекта, что круг правки 4 задачи 19 закрыл для
/// `terminal_changed`.
///
/// **Почему не в `wt_dispatcher._errorFor`, где живут два соседних кода.**
/// Потому что там это сломало бы вход. `WtAuthRepository.login` ловит
/// `WtProtocolError` с кодом `unknown_terminal` и делает из него
/// `UnknownTerminalException` — по ней вход сбрасывает кэш и заводит
/// терминал заново; переведи код в [SessionLost] наверху — и эта починка
/// перестанет срабатывать, потому что [SessionLost] не `WtProtocolError`.
/// Отличить одно от другого может только тот, кто знает имя операции, а
/// `_errorFor` его не знает. Общий случай (те же грабли ждут корзину и
/// оплату) назван работой, а не сделан молча здесь.
///
/// # Чего здесь нет: [abandon]
///
/// У неё нет операции провода, и это решение задачи 19, а не пропуск:
/// черновик забывает **касса**, обработчиком `auth.login`, когда за место
/// садится другой человек. Терминалу звать её незачем и нечем. Молчаливое
/// «ничего не делаем» было бы хуже отказа: метод, охраняющий деньги при
/// пересменке, обязан сказать, что на этой стороне провода его нет.
library;

import 'dart:async';

import 'package:decimal/decimal.dart';

import 'package:telepos/domain/refund/refund_service.dart';
import 'package:telepos/domain/sale/cart_view.dart';
import 'package:telepos/domain/sale/payment_service.dart'
    show CompletionTrouble;
import 'package:telepos/domain/wire/refund_ops.dart';
import 'package:telepos/domain/wire/session_lost.dart';
import 'package:telepos/domain/wire/wire_op.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';
import 'package:telepos/web/wt_channel.dart';
import 'package:telepos/web/wt_dispatcher.dart';

class WtRefundService implements RefundService {
  const WtRefundService(this._wire);

  final WtDispatcher _wire;

  /// Черновик возврата этого места сейчас и при каждом изменении.
  ///
  /// Подписка, а не опрос: черновик меняет касса (в том числе `abandon` на
  /// входе другого кассира), и экран обязан узнать об этом в момент
  /// изменения, а не при следующем нажатии.
  @override
  Stream<RefundView> watch(int terminalId) =>
      _wire.watch(RefundOps.view, null).transform(_refusals<RefundView>());

  @override
  Future<RefundView> loadReceipt(
    int terminalId,
    int receiptNo,
    int posId,
    CartCommandMeta meta,
  ) => _ask(
    RefundOps.loadReceipt,
    ReceiptKey(receiptNo: receiptNo, posId: posId, meta: meta),
  );

  @override
  Future<RefundView> startWithoutReceipt(
    int terminalId,
    CartCommandMeta meta,
  ) => _ask(RefundOps.startWithoutReceipt, meta);

  @override
  Future<RefundView> addProduct(
    int terminalId,
    int productId,
    Decimal quantity,
    CartCommandMeta meta,
  ) => _ask(
    RefundOps.addProduct,
    RefundLineRequest(productId: productId, quantity: quantity, meta: meta),
  );

  @override
  Future<RefundView> setLineQuantity(
    int terminalId,
    String lineId,
    Decimal quantity,
    CartCommandMeta meta,
  ) => _ask(
    RefundOps.setLine,
    RefundLineQuantity(lineId: lineId, quantity: quantity, meta: meta),
  );

  @override
  Future<RefundOutcome> complete(int terminalId, CartCommandMeta meta) =>
      _ask(RefundOps.complete, meta);

  /// `terminalId` на провод не уезжает — касса берёт место из сеанса (тот
  /// же довод, что у остальных команд и у `WtPaymentService.hardwareTroubles`).
  @override
  Future<List<CompletionTrouble>> hardwareTroubles(
    int terminalId,
    int refundLocalId,
  ) => _ask(RefundOps.troubles, refundLocalId);

  @override
  Future<void> abandon(int terminalId) async {
    throw const WireRefusal(
      'refund_abandon_is_till_side',
      'черновик возврата забывает касса на входе кассира — операции провода '
          'у этого действия нет',
    );
  }

  /// Один вопрос кассе с переводом отказа в тип контракта **и с пределом
  /// ожидания**.
  ///
  /// # Почему предел здесь, а не в диспетчере
  ///
  /// У обмена с кассой нет ни таймаута, ни отмены — это записано прямо в
  /// дереве (докстринг `LoginNotifier.logout`: «у обмена с ней нет ни
  /// таймаута, ни отмены, и молчащий провод не имеет права…»). Для подписки
  /// это верно: она и должна ждать сколько угодно. Для **команды возврата**
  /// — нет: кассир нажал кнопку денег, и если касса не ответила, он обязан
  /// об этом узнать, а не смотреть на невредимый черновик и гадать, нажалась
  /// ли кнопка.
  ///
  /// Живой прогон 2026-09-07 показал ровно эту картину: подтверждение
  /// закрыло диалог, черновик остался, ни успеха, ни отказа, ни строки в
  /// консоли. Молчание навсегда — худший из четырёх дефектов задачи, потому
  /// что кассир нажмёт ещё раз, и ещё, и будет прав.
  ///
  /// Предел ставится **в возврате**, а не в `WtDispatcher`: там он поменял
  /// бы поведение подписок и всех прочих операций разом, включая те, где
  /// долгое ожидание законно (`startup.restore` — восстановление магазина).
  ///
  /// # Почему отказ, а не повтор
  ///
  /// Команда возврата **не** идемпотентна для повторяющего: ключ повтора
  /// живёт на кассе, и слепой повтор из-за молчания провода — это ровно тот
  /// путь, которым возвращают деньги дважды. Терминал говорит «касса не
  /// ответила», а решает человек.
  static const _commandTimeout = Duration(seconds: 20);

  Future<Res> _ask<Req, Res>(Ask<Req, Res> op, Req request) async {
    try {
      return await _wire.ask(op, request).timeout(_commandTimeout);
    } on TimeoutException {
      throw WireRefusal(
        'no_answer',
        'касса не ответила за ${_commandTimeout.inSeconds} секунд — '
            'проверьте связь и посмотрите на кассе, прошёл ли возврат',
      );
    } on WtProtocolError catch (error) {
      throw _translate(error);
    }
  }

  /// Отказ провода → то, что понимает экран.
  ///
  /// `unknown_terminal` уходит [SessionLost]'ом: он лечится **только** входом
  /// заново (разбор в докстринге класса). Остальное — отказ операции с
  /// сохранённым кодом.
  static Object _translate(WtProtocolError error) =>
      error.code == 'unknown_terminal'
      ? SessionLost(error.detail, code: error.code)
      : WireRefusal(error.code, error.detail);

  /// То же для подписки: `handleError` не годится — он оставил бы исходное
  /// исключение в потоке, если бы обработчик сам ничего не бросил, и разница
  /// между «перевели» и «пропустили» была бы невидима.
  StreamTransformer<T, T> _refusals<T>() =>
      StreamTransformer<T, T>.fromHandlers(
        handleError: (error, stack, sink) {
          sink.addError(
            error is WtProtocolError ? _translate(error) : error,
            stack,
          );
        },
      );
}
