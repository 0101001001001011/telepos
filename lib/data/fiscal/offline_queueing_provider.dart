import 'package:telepos/domain/fiscal/fiscal_failure_reason.dart';
import 'package:telepos/domain/fiscal/fiscal_models.dart';
import 'package:telepos/domain/fiscal/fiscal_provider.dart';
import 'package:telepos/domain/fiscal/fiscal_settings.dart';

class FiscalQueueEntry {
  FiscalQueueEntry({
    required this.idempotencyKey,
    required this.opType,
    required this.payload,
    required this.occurredAt,
    this.status = FiscalQueueStatus.pending,
    this.attempts = 0,
    this.lastError,
  });

  final String idempotencyKey;

  final FiscalQueueOp opType;

  final Map<String, dynamic> payload;

  final DateTime occurredAt;

  FiscalQueueStatus status;
  int attempts;
  String? lastError;

  /// Ключ, которым **документ внутри [payload]** ходил к оператору.
  ///
  /// `null` — документа в payload нет вовсе (строка старого вида: записка
  /// `{receiptNo, posId, amount}`) или его ключ не читается.
  String? get documentKey {
    switch (opType) {
      case FiscalQueueOp.sale:
      case FiscalQueueOp.purchase:
      case FiscalQueueOp.moneyIn:
      case FiscalQueueOp.moneyOut:
        return payload['idempotencyKey'] as String?;
      case FiscalQueueOp.refund:
      case FiscalQueueOp.purchaseReturn:
        final sale = payload['sale'];
        return sale is Map ? sale['idempotencyKey'] as String? : null;
    }
  }

  /// Ключ **документа-основания**: от кого эта строка зависит поимённо.
  ///
  /// Есть только у возвратов и только начиная с 2026-09-19
  /// (`FiscalRefundBasis.originalIdempotencyKey`, там же разбор). `null` —
  /// «не назван»: возврат без чека, строка, легшая раньше правки, или
  /// документ, собранный не через `FiscalServiceImpl`. На `null` очередь
  /// возвращается к осторожному правилу — [FiscalQueueHold].
  String? get basisDocumentKey {
    switch (opType) {
      case FiscalQueueOp.sale:
      case FiscalQueueOp.purchase:
      case FiscalQueueOp.moneyIn:
      case FiscalQueueOp.moneyOut:
        return null;
      case FiscalQueueOp.refund:
      case FiscalQueueOp.purchaseReturn:
        final basis = payload['basis'];
        if (basis is! Map) return null;
        final key = basis['originalIdempotencyKey'];
        return (key is String && key.isNotEmpty) ? key : null;
    }
  }

  /// Строку **есть чем повторить**: она несёт сам документ, и ключ этого
  /// документа совпадает с ключом строки.
  ///
  /// # Почему совпадение ключей, а не «payload непустой»
  ///
  /// Повтор чужим ключом — не повтор. Дедупликация оператора узнаёт
  /// документ по `ExternalCheckNumber`; строка, у которой ключ свой
  /// («запись о беде»), а документ — чужой, при повторе дала бы **второй
  /// фискальный документ на одну продажу**. Ровно так и было до задачи 11:
  /// строка ложилась с ключом `sale-unfiscalized:$posId-$receiptNo`, а
  /// провайдер ходил с `sale-$receiptNo-$posId`.
  ///
  /// Строки, записанные **до** задачи 11, этой проверки не проходят и
  /// повтору не подлежат — их можно только списать рукой человека.
  bool get carriesDocument {
    final key = documentKey;
    if (key == null || key != idempotencyKey) return false;
    switch (opType) {
      case FiscalQueueOp.moneyIn:
      case FiscalQueueOp.moneyOut:
        return true;
      case FiscalQueueOp.sale:
      case FiscalQueueOp.purchase:
        final positions = payload['positions'];
        return positions is List && positions.isNotEmpty;
      case FiscalQueueOp.refund:
      case FiscalQueueOp.purchaseReturn:
        final sale = payload['sale'];
        if (sale is! Map) return false;
        final positions = sale['positions'];
        return positions is List && positions.isNotEmpty;
    }
  }

  /// Строка **разобрана человеком**: списана с названной причиной и
  /// именем. Не удалена — тихой чистки у этой очереди нет.
  FiscalQueueWriteOff? get writeOff {
    final raw = payload[kWriteOffKey];
    return raw is Map
        ? FiscalQueueWriteOff.fromJson(raw.cast<String, dynamic>())
        : null;
  }

  /// Ключ в [payload], под которым живёт отметка о списании.
  ///
  /// Живёт **рядом с документом, а не вместо него**: `FiscalSaleRequest
  /// .fromJson` лишних ключей не читает, поэтому списанная строка
  /// по-прежнему восстанавливается в тот же документ, и решение человека
  /// обратимо. Отдельной колонки под это не заводится — задача 11 идёт
  /// без миграции схемы намеренно.
  static const String kWriteOffKey = 'writtenOff';

  Map<String, dynamic> toJson() => {
    'idempotencyKey': idempotencyKey,
    'opType': opType.name,
    'payload': payload,
    'occurredAt': occurredAt.toIso8601String(),
    'status': status.name,
    'attempts': attempts,
    if (lastError != null) 'lastError': lastError,
  };

  factory FiscalQueueEntry.fromJson(Map<String, dynamic> json) =>
      FiscalQueueEntry(
        idempotencyKey: json['idempotencyKey'] as String? ?? '',
        opType: FiscalQueueOp.values.byName(
          json['opType'] as String? ?? 'sale',
        ),
        payload: (json['payload'] as Map?)?.cast<String, dynamic>() ?? const {},
        occurredAt:
            DateTime.tryParse(json['occurredAt'] as String? ?? '') ??
            DateTime.now(),
        status: FiscalQueueStatus.values.byName(
          json['status'] as String? ?? 'pending',
        ),
        attempts: json['attempts'] as int? ?? 0,
        lastError: json['lastError'] as String?,
      );
}

enum FiscalQueueOp { sale, refund, purchase, purchaseReturn, moneyIn, moneyOut }

/// **От чего именно зависит документ** — три разных ответа, а не два.
///
/// До 2026-09-19 ответов было два: «зависит» и «нет», — и «зависит»
/// означало «держится за **любую** застрявшую строку». Цена этой
/// осторожности измерена у заказчика: чек, который оператор отказался
/// принять, останавливал фискализацию **посторонних** документов — возврат
/// по чужому чеку не уезжал, потому что чья-то продажа застряла.
///
/// Родов теперь три, и каждый назван тем, от чего зависит на самом деле.
enum FiscalQueueDependency {
  /// Ни от чего: [FiscalQueueOp.sale] и [FiscalQueueOp.moneyIn]. Только
  /// прибавляют деньги в ящик и не ссылаются ни на один прежний документ.
  none,

  /// От **своего** документа-основания и ничьего больше:
  /// [FiscalQueueOp.refund] и [FiscalQueueOp.purchaseReturn].
  ///
  /// Возврат несёт признак основания (`FiscalRefundBasis.originalFiscalSign`),
  /// а у застрявшей продажи признака ещё нет — значит возврат **именно
  /// этой** продажи оператор отвергнет. Возврат любого другого чека к ней
  /// отношения не имеет: его основание уже у оператора, признак в конверте
  /// настоящий, и держать его не за что.
  ///
  /// Какая продажа «своя», читается из
  /// `FiscalRefundBasis.originalIdempotencyKey`. Ключа нет — правило
  /// возвращается к [drawerBalance], то есть к прежней осторожности:
  /// «не знаем, чьё основание» не то же самое, что «ничьё».
  ownBasis,

  /// От **остатка в ящике**, то есть от всех прежних документов разом:
  /// [FiscalQueueOp.purchase] и [FiscalQueueOp.moneyOut].
  ///
  /// Они забирают из ящика деньги, положенные туда прежними документами, и
  /// оператор отвечает кодом 8 «недостаточно денег». Здесь осторожность
  /// **не** ослаблена, и это не недоделка: сослаться не на что: у изъятия
  /// нет документа-основания, зависимость у него арифметическая — остаток.
  /// Назвать её точно значило бы вести у кассы собственный счёт ящика
  /// оператора, а он у нас не сходится по построению (часть документов
  /// висит в очереди, часть уехала, часть отвергнута).
  drawerBalance,
}

/// **Порядок документов: кто может идти мимо застрявшего.**
///
/// `switch` исчерпывающий и без `default`: новый вид операции не соберётся,
/// пока ему не назван род.
extension FiscalQueueOpOrder on FiscalQueueOp {
  FiscalQueueDependency get dependency => switch (this) {
    FiscalQueueOp.sale => FiscalQueueDependency.none,
    FiscalQueueOp.moneyIn => FiscalQueueDependency.none,
    FiscalQueueOp.refund => FiscalQueueDependency.ownBasis,
    FiscalQueueOp.purchaseReturn => FiscalQueueDependency.ownBasis,
    FiscalQueueOp.purchase => FiscalQueueDependency.drawerBalance,
    FiscalQueueOp.moneyOut => FiscalQueueDependency.drawerBalance,
  };
}

/// Держать ли строку — **правило одно на оба входа**.
///
/// Входа два, и это не украшение: новый документ приходит через
/// `OfflineQueueingProvider._guard` (очередь читается целиком), а ждущая
/// строка — через проход повтора (очередь читается по ходу, и часть строк
/// уже разобрана). Разойдись эти два места — и новый возврат уезжал бы
/// сразу, а тот же возврат из очереди держался бы, или наоборот.
///
/// # Правило
///
/// * [FiscalQueueDependency.none] — не держать никогда;
/// * [FiscalQueueDependency.ownBasis] с известным ключом основания —
///   держать, **только** пока это основание не у оператора;
/// * [FiscalQueueDependency.ownBasis] без ключа и
///   [FiscalQueueDependency.drawerBalance] — держать по [coarseBlocked],
///   то есть по прежнему осторожному правилу.
///
/// # Что такое [coarseBlocked] на каждом из входов
///
/// Оно **разное по способу счёта и одинаковое по смыслу**: «есть
/// неразобранное, за что положено держаться».
///
/// * у нового документа (`_guard`) — очередь непуста: всё, что в ней
///   лежит, у оператора ещё не было;
/// * в проходе повтора — раньше по ходу застряла строка. Строки
///   **позже** по ходу сюда не считаются намеренно: очередь
///   упорядочена по времени документа, и то, что случилось после
///   изъятия, денег в ящике к моменту изъятия не добавляло.
///
/// # Чего это НЕ доказывает
///
/// Что отпущенный возврат оператор примет. Здесь решается **только**
/// порядок отправки: что документ не будет отвергнут из-за того, что его
/// основание ещё в очереди. Отвергнуть его оператор может по любой своей
/// причине, и тогда отказ ляжет в `failed` по делу, с названной причиной.
abstract final class FiscalQueueHold {
  static bool holds({
    required FiscalQueueOp op,
    required String? basisKey,
    required bool coarseBlocked,
    required bool Function(String key) basisStillInQueue,
  }) {
    switch (op.dependency) {
      case FiscalQueueDependency.none:
        return false;
      case FiscalQueueDependency.ownBasis:
        if (basisKey == null) return coarseBlocked;
        return basisStillInQueue(basisKey);
      case FiscalQueueDependency.drawerBalance:
        return coarseBlocked;
    }
  }
}

enum FiscalQueueStatus { pending, done, failed }

/// Отметка «разобрано человеком»: кто списал, когда и по какой причине.
///
/// Причина и имя **обязательны**: списание нефискализованного чека — это
/// решение о документе, которого у продажи не будет никогда, и безымянное
/// решение здесь неотличимо от тихой чистки.
class FiscalQueueWriteOff {
  const FiscalQueueWriteOff({
    required this.at,
    required this.by,
    required this.reason,
  });

  final DateTime at;

  /// Имя человека, принявшего решение.
  final String by;

  final String reason;

  Map<String, dynamic> toJson() => {
    'at': at.toIso8601String(),
    'by': by,
    'reason': reason,
  };

  factory FiscalQueueWriteOff.fromJson(Map<String, dynamic> json) =>
      FiscalQueueWriteOff(
        at: DateTime.tryParse(json['at'] as String? ?? '') ?? DateTime.now(),
        by: json['by'] as String? ?? '',
        reason: json['reason'] as String? ?? '',
      );
}

abstract interface class FiscalQueueStore {
  Future<void> enqueue(FiscalQueueEntry entry);

  Future<List<FiscalQueueEntry>> pending();

  /// Строки, которые **никто не подберёт**: нетранзиентный отказ оператора
  /// или чек, переживший автономное окно.
  ///
  /// Третье **чтение**, а не третий статус: колонка `status` уже хранит
  /// `failed`, миграции схемы задача 11 не делает. До неё это состояние
  /// писалось и не читалось ничем — строки копились навсегда и не были
  /// видны ни одному экрану.
  ///
  /// Порядок — от старой к новой, тем же правилом, что и [pending]:
  /// первой разбирают ту, у которой скорее вышло окно 72 часа.
  Future<List<FiscalQueueEntry>> failed();

  Future<void> update(FiscalQueueEntry entry);

  Future<void> remove(String idempotencyKey);

  Future<int> pendingCount();

  /// Сколько чеков ждут человека. Списанные ([FiscalQueueEntry.writeOff])
  /// не считаются: они уже разобраны.
  Future<int> failedCount();
}

class InMemoryFiscalQueueStore implements FiscalQueueStore {
  final Map<String, FiscalQueueEntry> _entries = {};

  @override
  Future<void> enqueue(FiscalQueueEntry entry) async {
    _entries.putIfAbsent(entry.idempotencyKey, () => entry);
  }

  @override
  Future<List<FiscalQueueEntry>> pending() async {
    final list =
        _entries.values
            .where((e) => e.status == FiscalQueueStatus.pending)
            .toList()
          ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
    return list;
  }

  @override
  Future<List<FiscalQueueEntry>> failed() async {
    final list =
        _entries.values
            .where((e) => e.status == FiscalQueueStatus.failed)
            .toList()
          ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
    return list;
  }

  @override
  Future<void> update(FiscalQueueEntry entry) async {
    _entries[entry.idempotencyKey] = entry;
  }

  @override
  Future<void> remove(String idempotencyKey) async {
    _entries.remove(idempotencyKey);
  }

  @override
  Future<int> pendingCount() async => (await pending()).length;

  @override
  Future<int> failedCount() async =>
      (await failed()).where((e) => e.writeOff == null).length;
}

typedef FiscalReachabilityCheck = Future<bool> Function();

class FiscalReplayReport {
  const FiscalReplayReport({
    this.fiscalized = 0,
    this.duplicates = 0,
    this.failed = 0,
    this.remaining = 0,
    this.stoppedOnNetwork = false,
    this.deferred = 0,
    this.held = 0,
  });

  final int fiscalized;

  /// Строки, на которые оператор ответил «документ с этим ключом уже
  /// зарегистрирован» (WebKassa, код 14): переведены в `failed` и отданы
  /// **человеку**.
  ///
  /// # Почему поле переименовано из `deduped`
  ///
  /// Прежнее имя описывало прежнее действие — строка **удалялась**, как
  /// будто беды нет. Беда есть, и она денежная: признака документа касса
  /// не получила (протокол его по ключу не отдаёт — разбор в докстринге
  /// `WebKassaProvider._checkResult`), значит у продажи нет фискального
  /// признака ни в `WebkassaReceipts`, ни на чеке покупателя, а строка,
  /// которой больше нет в очереди, не видна ни одному экрану. «Дедуп» —
  /// это про то, что второго документа у оператора не завелось; про
  /// деньги кассы он не говорит ничего.
  ///
  /// Счётчик поэтому считает не убранное, а **переданное человеку**: его
  /// строки попадают на экран нефискализованных чеков и в число
  /// `ShiftService.unfiscalizedAtClose`.
  final int duplicates;

  final int failed;

  final int remaining;

  /// Проход оставил строки ждать из-за транзиентного отказа — или не начался,
  /// потому что оператор недоступен.
  final bool stoppedOnNetwork;

  /// Строки с транзиентным отказом в этом проходе: остались `pending`,
  /// попытка сосчитана.
  final int deferred;

  /// Зависимые строки, **не отправленные** потому, что не уехало то, от
  /// чего они зависят: у возврата — его собственное основание, у изъятия —
  /// деньги в ящике. Правило целиком — [FiscalQueueHold].
  final int held;
}

const Duration kOfflineFiscalWindow = Duration(hours: 72);

class OfflineQueueingProvider implements FiscalProvider {
  OfflineQueueingProvider({
    required this.inner,
    required this.store,
    required FiscalReachabilityCheck isReachable,
    this.offlineWindow = kOfflineFiscalWindow,
    this.maxConsecutiveTransient = 3,
    this.onOperatorReached,
    DateTime Function()? now,
  }) : _isReachable = isReachable,
       _now = now ?? DateTime.now;

  final FiscalProvider inner;

  final FiscalQueueStore store;

  final FiscalReachabilityCheck _isReachable;

  final Duration offlineWindow;

  /// Сколько транзиентных отказов **подряд** проход терпит, прежде чем
  /// признать, что лежит связь, а не одна строка.
  ///
  /// Одна строка с обрывом не должна хоронить остальные — но при настоящем
  /// обрыве каждая строка стоит тайм-аута клиента (30 с), и проход по
  /// пятистам строкам занял бы четыре часа. Три подряд — уже не случайность;
  /// остальное подберёт следующий проход.
  final int maxConsecutiveTransient;

  /// Зовётся, когда живой документ **дошёл до оператора** — это
  /// единственный в кассе признак восстановленной связи
  /// (`isReachable` в сборке кассы — `() async => true`). Планировщик
  /// повтора подписывается сюда, чтобы не ждать своего круга.
  final void Function()? onOperatorReached;

  final DateTime Function() _now;

  /// Замок прохода — **на хранилище, а не на экземпляре**: реестр строит
  /// провайдер заново на каждый `resolve`, и два экземпляра над одной
  /// очередью иначе отправили бы одну строку дважды (измерено: две
  /// отправки одной строки на два одновременных прохода).
  static final Expando<_ReplayGate> _gates = Expando('fiscal-replay-gate');

  @override
  String get id => inner.id;

  @override
  FiscalCapabilities get capabilities => inner.capabilities;

  @override
  String? validateConfig(FiscalSettings config) => inner.validateConfig(config);

  @override
  Future<FiscalAuthResult> authorize(FiscalSettings config) =>
      inner.authorize(config);

  @override
  Future<FiscalResult> fiscalizeSale(FiscalSaleRequest req) => _guard(
    FiscalQueueOp.sale,
    req.idempotencyKey,
    req.occurredAt,
    req.toJson,
    () => inner.fiscalizeSale(req),
  );

  @override
  Future<FiscalResult> fiscalizeRefund(FiscalRefundRequest req) => _guard(
    FiscalQueueOp.refund,
    req.sale.idempotencyKey,
    req.sale.occurredAt,
    req.toJson,
    () => inner.fiscalizeRefund(req),
    basisKey: req.basis.originalIdempotencyKey,
  );

  @override
  Future<FiscalResult> fiscalizePurchase(FiscalSaleRequest req) => _guard(
    FiscalQueueOp.purchase,
    req.idempotencyKey,
    req.occurredAt,
    req.toJson,
    () => inner.fiscalizePurchase(req),
  );

  @override
  Future<FiscalResult> fiscalizePurchaseReturn(FiscalRefundRequest req) =>
      _guard(
        FiscalQueueOp.purchaseReturn,
        req.sale.idempotencyKey,
        req.sale.occurredAt,
        req.toJson,
        () => inner.fiscalizePurchaseReturn(req),
        basisKey: req.basis.originalIdempotencyKey,
      );

  @override
  Future<FiscalResult> moneyIn(FiscalMoneyRequest req) => _guard(
    FiscalQueueOp.moneyIn,
    req.idempotencyKey,
    req.occurredAt,
    req.toJson,
    () => inner.moneyIn(req),
  );

  @override
  Future<FiscalResult> moneyOut(FiscalMoneyRequest req) => _guard(
    FiscalQueueOp.moneyOut,
    req.idempotencyKey,
    req.occurredAt,
    req.toJson,
    () => inner.moneyOut(req),
  );

  Future<FiscalResult> _guard(
    FiscalQueueOp op,
    String idempotencyKey,
    DateTime occurredAt,
    Map<String, dynamic> Function() payload,
    Future<FiscalResult> Function() call, {
    String? basisKey,
  }) async {
    if (!await _reachableSafe()) {
      return _enqueue(op, idempotencyKey, occurredAt, payload());
    }
    // Зависимый документ не обходит **того, от кого зависит**: возврат,
    // ушедший раньше своей продажи из очереди, оператор отвергнет. Встаёт
    // за ней — повтор повезёт в порядке `occurredAt`.
    //
    // Чужая застрявшая строка его больше не держит (правка 2026-09-19,
    // разбор — `FiscalQueueDependency`): до неё возврат по чужому чеку
    // ложился в очередь только потому, что у соседа не уехала продажа.
    if (await _heldByQueueSafe(op, basisKey)) {
      return _enqueue(op, idempotencyKey, occurredAt, payload());
    }
    final FiscalResult result;
    try {
      result = await call();
    } catch (_) {
      return _enqueue(op, idempotencyKey, occurredAt, payload());
    }
    if (result.success) {
      if (!result.queued) _operatorReached();
      return result;
    }
    if (!_isTransient(result.errorCode)) {
      // Нетранзиентный ответ — тоже ответ оператора: связь есть.
      _operatorReached();
    }
    if (_isTransient(result.errorCode)) {
      return _enqueue(op, idempotencyKey, occurredAt, payload());
    }
    return result;
  }

  Future<FiscalResult> _enqueue(
    FiscalQueueOp op,
    String idempotencyKey,
    DateTime occurredAt,
    Map<String, dynamic> payload,
  ) async {
    await store.enqueue(
      FiscalQueueEntry(
        idempotencyKey: idempotencyKey,
        opType: op,
        payload: payload,
        occurredAt: occurredAt,
      ),
    );
    return FiscalResult.queued();
  }

  Future<bool> _reachableSafe() async {
    try {
      return await _isReachable();
    } catch (_) {
      return false;
    }
  }

  /// Таблица — одна, в домене: `FiscalErrorCodeRetry.isTransient`
  /// (`fiscal_models.dart`). Здесь её не дублировать.
  static bool _isTransient(FiscalErrorCode code) => code.isTransient;

  /// Держит ли очередь **новый** документ этого рода.
  ///
  /// Хранилище, которое не читается, считается пустым: отказать живому
  /// чеку из-за сломанной очереди хуже, чем отправить его. Прежний код
  /// молчал здесь ровно так же (`_hasPendingSafe` → `false` в `catch`),
  /// поведение не меняется — меняется только то, что причина названа.
  Future<bool> _heldByQueueSafe(FiscalQueueOp op, String? basisKey) async {
    if (op.dependency == FiscalQueueDependency.none) return false;
    try {
      final pending = await store.pending();
      final keys = pending.map((e) => e.idempotencyKey).toSet();
      return FiscalQueueHold.holds(
        op: op,
        basisKey: basisKey,
        coarseBlocked: pending.isNotEmpty,
        basisStillInQueue: keys.contains,
      );
    } catch (_) {
      return false;
    }
  }

  void _operatorReached() {
    final hook = onOperatorReached;
    if (hook == null) return;
    try {
      hook();
    } catch (_) {
      // Подписчик не имеет права уронить фискализацию.
    }
  }

  /// Один проход по `pending`.
  ///
  /// # Проходы не пересекаются
  ///
  /// Пока идёт проход над этим хранилищем, новый вызов **не начинает
  /// второй**, а встаёт следующим — и все, кто позвал во время прохода,
  /// получают этот один следующий. Строка не уходит дважды, а строка,
  /// легшая во время прохода, подбирается следующим, а не теряется.
  ///
  /// # Правило обхода
  ///
  /// * успех — строка убрана;
  /// * `duplicate` (код 14) — строка **не убрана**, а переведена в `failed`
  ///   с названной причиной `fiscal(duplicate#14)`: документ у оператора
  ///   есть, а фискального признака касса не получила и получить не может.
  ///   Разбор — [FiscalReplayReport.duplicates];
  /// * транзиентный отказ (`FiscalErrorCode.isTransient`) — строка остаётся
  ///   `pending`, попытка и причина записаны, **обход продолжается**; за
  ///   ней держатся только те, кто от неё зависит, — её собственные
  ///   возвраты поимённо и изъятия из ящика ([FiscalQueueHold]);
  /// * [maxConsecutiveTransient] транзиентных подряд — проход кончается:
  ///   лежит связь, а не строка;
  /// * нетранзиентный отказ — `failed`, на экран нефискализованных чеков;
  /// * бросок при разборе строки (документ не восстанавливается) — тоже
  ///   `failed`: повтор повторит бросок. До правки он останавливал весь
  ///   обход как обрыв сети.
  Future<FiscalReplayReport> replay() {
    final gate = _gates[store] ??= _ReplayGate();
    final running = gate.running;
    if (running == null) return _startPass(gate);
    return gate.queued ??= running
        .then<void>((_) {}, onError: (Object _) {})
        .then((_) {
          gate.queued = null;
          return _startPass(gate);
        });
  }

  Future<FiscalReplayReport> _startPass(_ReplayGate gate) {
    final pass = _replayPass();
    gate.running = pass;
    pass.then<void>((_) {}, onError: (Object _) {}).whenComplete(() {
      if (identical(gate.running, pass)) gate.running = null;
    });
    return pass;
  }

  Future<FiscalReplayReport> _replayPass() async {
    if (!await _reachableSafe()) {
      final remaining = await store.pendingCount();
      return FiscalReplayReport(remaining: remaining, stoppedOnNetwork: true);
    }

    var fiscalized = 0;
    var duplicates = 0;
    var failed = 0;
    var deferred = 0;
    var held = 0;
    var blocked = false;
    var consecutiveTransient = 0;
    var cut = false;

    final entries = await store.pending();

    /// Ключи строк, которых у оператора **ещё нет** на эту секунду прохода.
    ///
    /// Убираются по мере разбора: успех — документ у оператора; код 14 —
    /// тоже у оператора (второго не завелось, ради этого ключ и
    /// существует); нетранзиентный отказ и истёкшее окно — документа не
    /// будет никогда, и держать за него возврат значит держать вечно
    /// (возврат уедет и получит **свой** названный отказ, а не чужой).
    /// Остаётся в наборе только отложенная транзиентно строка — та, что
    /// ещё доедет.
    final stillQueued = {for (final e in entries) e.idempotencyKey};

    for (final entry in entries) {
      if (_now().difference(entry.occurredAt) > offlineWindow) {
        entry
          ..status = FiscalQueueStatus.failed
          ..lastError = const FiscalFailureReason(
            FiscalFailureKind.offlineWindowExpired,
          ).encode();
        await store.update(entry);
        stillQueued.remove(entry.idempotencyKey);
        failed++;
        continue;
      }

      if (FiscalQueueHold.holds(
        op: entry.opType,
        basisKey: entry.basisDocumentKey,
        coarseBlocked: blocked,
        basisStillInQueue: stillQueued.contains,
      )) {
        held++;
        continue;
      }

      if (consecutiveTransient >= maxConsecutiveTransient) {
        cut = true;
        break;
      }

      final FiscalResult result;
      try {
        result = await _dispatch(entry);
      } catch (e) {
        entry
          ..status = FiscalQueueStatus.failed
          ..attempts = entry.attempts + 1
          ..lastError = const FiscalFailureReason(
            FiscalFailureKind.rowUnreadable,
          ).encode();
        await store.update(entry);
        stillQueued.remove(entry.idempotencyKey);
        failed++;
        continue;
      }

      if (result.success) {
        await store.remove(entry.idempotencyKey);
        stillQueued.remove(entry.idempotencyKey);
        fiscalized++;
        consecutiveTransient = 0;
      } else if (result.errorCode == FiscalErrorCode.duplicate) {
        // Документ у оператора уже есть — второго не завелось, и ради этого
        // ключ идемпотентности и существует. Но **признака у кассы нет**, и
        // взять его неоткуда: ни один путь протокола не отдаёт документ по
        // `ExternalCheckNumber`. Убрать строку значило бы сказать «всё
        // сошлось» о чеке, у которого признака нет ни в `WebkassaReceipts`,
        // ни на бумаге у покупателя, — и не оставить следа нигде.
        //
        // Поэтому строка идёт **к человеку**, а не в корзину: `failed` с
        // названной причиной виден на экране нефискализованных чеков, где
        // признак доносят из кабинета оператора и списывают строку с
        // именем и причиной. Слепого повтора она не получит — `duplicate`
        // нетранзиентный, а `replay` читает только `pending`.
        entry
          ..status = FiscalQueueStatus.failed
          ..attempts = entry.attempts + 1
          ..lastError = FiscalFailureReason.fromResult(result).encode();
        await store.update(entry);
        // Зависимые за ней **не держатся**: держат тех, чьё основание ещё
        // не у оператора, а это основание у него как раз есть.
        stillQueued.remove(entry.idempotencyKey);
        duplicates++;
        consecutiveTransient = 0;
      } else if (_isTransient(result.errorCode)) {
        entry
          ..attempts = entry.attempts + 1
          ..lastError = FiscalFailureReason.fromResult(result).encode();
        await store.update(entry);
        deferred++;
        blocked = true;
        consecutiveTransient++;
      } else {
        entry
          ..status = FiscalQueueStatus.failed
          ..attempts = entry.attempts + 1
          ..lastError = FiscalFailureReason.fromResult(result).encode();
        await store.update(entry);
        // Документа по этой строке не будет никогда. Возврат, который на
        // неё ссылается, отпускается: пусть получит **свой** названный
        // отказ у оператора и ляжет к человеку рядом с основанием, а не
        // висит ждущим до конца автономного окна.
        stillQueued.remove(entry.idempotencyKey);
        failed++;
        consecutiveTransient = 0;
      }
    }

    return FiscalReplayReport(
      fiscalized: fiscalized,
      duplicates: duplicates,
      failed: failed,
      deferred: deferred,
      held: held,
      remaining: await store.pendingCount(),
      stoppedOnNetwork: cut || deferred > 0,
    );
  }

  /// Повторить **одну** строку отказа — по нажатию человека, а не сама.
  ///
  /// # Почему это отдельный вход, а не расширение [replay]
  ///
  /// [replay] читает `pending` и подбирает то, что лечится временем:
  /// `network` и `tokenExpired`. Строка со статусом `failed` — это
  /// нетранзиентный отказ (неверные учётные данные, заблокированная касса,
  /// отвергнутый документ) или чек, переживший автономное окно. Слепой
  /// повтор такого — вечный цикл; лечит его человек, который сначала
  /// исправил причину. Автоматического повтора у этих строк не появляется
  /// и здесь: этот метод зовёт экран, а не таймер.
  ///
  /// # Повторяется **сохранённый документ**, а не пересобранный
  ///
  /// Ровно то, что уехало оператору в первый раз, с тем же
  /// `ExternalCheckNumber`. Пересборка из базы чека уехала бы с другим
  /// ключом — и на одну продажу приехали бы два фискальных документа,
  /// потому что дедупликация оператора второго ключа не узнаёт.
  ///
  /// Строку без документа ([FiscalQueueEntry.carriesDocument] ложно)
  /// повторять нечем, и метод отказывает **значением**, а не броском:
  /// такие строки писались до задачи 11 и подлежат только списанию.
  Future<FiscalResult> retryFailed(FiscalQueueEntry entry) async {
    if (!entry.carriesDocument) {
      return FiscalResult.failure(
        'Строка записана до того, как отказы стали нести документ: '
        'повторять нечем, её можно только списать',
        code: FiscalErrorCode.validation,
      );
    }

    final FiscalResult result;
    try {
      result = await _dispatch(entry);
    } catch (e) {
      entry
        ..attempts = entry.attempts + 1
        ..lastError = const FiscalFailureReason(
          FiscalFailureKind.clientFault,
        ).encode();
      await store.update(entry);
      return FiscalResult.failure(
        'Оператор недоступен',
        code: FiscalErrorCode.network,
      );
    }

    if (result.success) {
      await store.remove(entry.idempotencyKey);
      return result;
    }

    // `duplicate` (код 14) строку **не снимает**, и это правка 2026-09-19.
    // Прежний довод звучал так: «документ у оператора уже есть; держать
    // строку дальше значило бы звать человека к чеку, у которого беды
    // нет». Беда есть: у оператора документ, у кассы — ни признака, ни
    // записи в `WebkassaReceipts`, а у покупателя чек, по которому этот
    // документ не найти. Снятая строка уносила с собой последний след
    // этого расхождения, и повтор рукой выглядел как починка.
    //
    // Человек, нажавший «Повторить», теперь читает названную причину
    // (`fiscalReasonDuplicate`) и закрывает строку **списанием с именем и
    // причиной** — после того, как сверит документ в кабинете оператора.
    // Это единственное закрытие, которое здесь честно: признака касса не
    // узнает ни одним путём протокола.

    entry
      ..attempts = entry.attempts + 1
      ..lastError = FiscalFailureReason.fromResult(result).encode();
    await store.update(entry);
    return result;
  }

  /// Списать строку рукой человека: **пометить разобранной**, не удаляя.
  ///
  /// Причина и имя обязательны — см. [FiscalQueueWriteOff]. Отметка ложится
  /// рядом с документом, поэтому решение обратимо и след остаётся.
  Future<void> writeOffFailed(
    FiscalQueueEntry entry, {
    required String by,
    required String reason,
    DateTime? at,
  }) async {
    final trimmedBy = by.trim();
    final trimmedReason = reason.trim();
    if (trimmedBy.isEmpty || trimmedReason.isEmpty) {
      throw ArgumentError('Списание требует имени и причины');
    }
    entry.payload[FiscalQueueEntry.kWriteOffKey] = FiscalQueueWriteOff(
      at: at ?? _now(),
      by: trimmedBy,
      reason: trimmedReason,
    ).toJson();
    entry.status = FiscalQueueStatus.failed;
    await store.update(entry);
  }

  Future<FiscalResult> _dispatch(FiscalQueueEntry entry) {
    switch (entry.opType) {
      case FiscalQueueOp.sale:
        return inner.fiscalizeSale(FiscalSaleRequest.fromJson(entry.payload));
      case FiscalQueueOp.refund:
        return inner.fiscalizeRefund(
          FiscalRefundRequest.fromJson(entry.payload),
        );
      case FiscalQueueOp.purchase:
        return inner.fiscalizePurchase(
          FiscalSaleRequest.fromJson(entry.payload),
        );
      case FiscalQueueOp.purchaseReturn:
        return inner.fiscalizePurchaseReturn(
          FiscalRefundRequest.fromJson(entry.payload),
        );
      case FiscalQueueOp.moneyIn:
        return inner.moneyIn(FiscalMoneyRequest.fromJson(entry.payload));
      case FiscalQueueOp.moneyOut:
        return inner.moneyOut(FiscalMoneyRequest.fromJson(entry.payload));
    }
  }

  Future<int> pendingCount() => store.pendingCount();

  @override
  Future<FiscalResult> openShift(FiscalShiftRequest req) =>
      inner.openShift(req);

  @override
  Future<FiscalReportResult> closeShift(FiscalShiftRequest req) =>
      inner.closeShift(req);

  @override
  Future<FiscalReportResult> xReport(FiscalShiftRequest req) =>
      inner.xReport(req);

  @override
  Future<FiscalResult> correctionReceipt(FiscalCorrectionRequest req) =>
      inner.correctionReceipt(req);

  @override
  Future<FiscalStatus> getStatus() => inner.getStatus();
}

/// Идущий проход над одним хранилищем и тот один, что встанет за ним.
class _ReplayGate {
  Future<FiscalReplayReport>? running;
  Future<FiscalReplayReport>? queued;
}
