/// Подделка возврата, которая помнит, звали ли её и с какими доводами —
/// задача 19 плана «Продажа с браузерного терминала».
///
/// **Почему подделка, а не `LocalRefundService` поверх настоящей базы.** Эти
/// наборы проверяют две вещи, которых у настоящей реализации нет: что сторож
/// отказывает **до** обработчика (то есть что реализацию не тронули вовсе) и
/// что имя рабочего места пришло из сеанса, а не из тела. Оба утверждения —
/// про то, что было **передано** в контракт, и настоящая реализация их не
/// показывает: она отвечает по существу и молчит о том, кто её звал. Само
/// поведение возврата проверено там, где ему место, — 45 тестов
/// `test/data/refund/local_refund_service_test.dart` на настоящей базе без
/// моков (задача 18).
library;

import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:telepos/domain/refund/refund_service.dart';
import 'package:telepos/domain/sale/cart_view.dart';
import 'package:telepos/domain/sale/payment_service.dart'
    show CompletionTrouble;
import 'package:telepos/domain/wire/wire_refusal.dart';

class RecordingRefund implements RefundService {
  /// Имена позванных методов, в порядке вызова. Пусто — контракт не тронут.
  final List<String> calls = [];

  /// Имя рабочего места, с которым позвали последний раз.
  int? lastTerminalId;

  /// Метка команды последнего вызова.
  CartCommandMeta? lastMeta;

  /// Доводы последнего вызова сверх метки — по одному ключу на довод.
  Map<String, Object?> lastArguments = const {};

  /// Отказ, который отдаст следующий вызов вместо ответа. Заводится в пробе
  /// «отказ реализации доезжает своим кодом»: касса обязана переводить его в
  /// кадр отказа, а не в общий `handler_failed`.
  WireRefusal? refuseWith;

  /// Снимок, который отдают все команды и подписка.
  RefundView view = const RefundView(
    posId: 1,
    terminalId: 7,
    version: 0,
    lines: [],
  );

  /// Исход, который отдаёт [complete].
  RefundOutcome outcome = RefundOutcome(
    refundLocalId: 9,
    amount: Decimal.parse('390.5'),
    lineCount: 2,
    paymentCount: 1,
    saleReceiptNo: 501,
    salePosId: 1,
  );

  T _record<T>(
    String name,
    int terminalId,
    CartCommandMeta? meta,
    Map<String, Object?> arguments,
    T answer,
  ) {
    calls.add(name);
    lastTerminalId = terminalId;
    lastMeta = meta;
    lastArguments = arguments;
    final refusal = refuseWith;
    if (refusal != null) throw refusal;
    return answer;
  }

  /// Запись и отказ — **синхронно**, до возврата потока: подписка, которую
  /// не удалось завести, обязана стать кадром отказа, а не потоком без
  /// событий (`TillWire._subscribe` ловит [WireRefusal] именно здесь).
  @override
  Stream<RefundView> watch(int terminalId) {
    _record<void>('watch', terminalId, null, const {}, null);
    return _live();
  }

  /// Не завершается: подписка, которая сама себя закрывает, доказывала бы
  /// про `TillWire` поведение на кончившемся источнике, а не на живом (тот
  /// же довод, что у `RecordingTerminals.watchAll`).
  ///
  /// **Контроллер, а не `async*` с вечным `await`,** и это не стиль:
  /// генератор, замерший на никогда не завершающемся будущем, **нельзя
  /// отменить** — `TillWire.stop()` ждал бы его вечно, и проба зависала бы
  /// в уборке, а не падала по существу (измерено: 30 секунд до
  /// `TimeoutException`). Поток контроллера точно так же не кончается сам, но
  /// снимается уходом подписчика — именно то, что делает `TillWire`.
  Stream<RefundView> _live() {
    final live = StreamController<RefundView>();
    // Значение кладётся до подписчика: обычный (не широковещательный)
    // контроллер придержит его до первого слушателя, и «касса говорит
    // первой» остаётся правдой независимо от того, кто успел раньше.
    live.add(view);
    return live.stream;
  }

  @override
  Future<RefundView> loadReceipt(
    int terminalId,
    int receiptNo,
    int posId,
    CartCommandMeta meta,
  ) async => _record('loadReceipt', terminalId, meta, {
    'receiptNo': receiptNo,
    'posId': posId,
  }, view);

  @override
  Future<RefundView> startWithoutReceipt(
    int terminalId,
    CartCommandMeta meta,
  ) async => _record('startWithoutReceipt', terminalId, meta, const {}, view);

  @override
  Future<RefundView> addProduct(
    int terminalId,
    int productId,
    Decimal quantity,
    CartCommandMeta meta,
  ) async => _record('addProduct', terminalId, meta, {
    'productId': productId,
    'quantity': quantity,
  }, view);

  @override
  Future<RefundView> setLineQuantity(
    int terminalId,
    String lineId,
    Decimal quantity,
    CartCommandMeta meta,
  ) async => _record('setLineQuantity', terminalId, meta, {
    'lineId': lineId,
    'quantity': quantity,
  }, view);

  @override
  Future<RefundOutcome> complete(int terminalId, CartCommandMeta meta) async =>
      _record('complete', terminalId, meta, const {}, outcome);

  /// Уборка при смене кассира — круг правки 1 задачи 19. Записывается наравне
  /// с командами: пробы про права проверяют, что до реализации **вообще не
  /// дошли**, и незаписанная уборка сделала бы это утверждение слабее, чем
  /// оно звучит.
  ///
  /// [refuseWith] здесь не действует: уборка отказов не отдаёт (идемпотентна
  /// по договору), и подмешивать ей чужой отказ значило бы проверять
  /// поведение, которого у неё нет.
  /// Беды железа, которые отдаст [hardwareTroubles].
  List<CompletionTrouble> troubles = const [];

  @override
  Future<List<CompletionTrouble>> hardwareTroubles(
    int terminalId,
    int refundLocalId,
  ) async => _record('hardwareTroubles', terminalId, null, {
    'refundLocalId': refundLocalId,
  }, troubles);

  @override
  Future<void> abandon(int terminalId) async {
    calls.add('abandon');
    lastTerminalId = terminalId;
  }
}
