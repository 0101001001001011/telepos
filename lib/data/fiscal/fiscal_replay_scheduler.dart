import 'dart:async';

import 'package:talker/talker.dart';
import 'package:telepos/data/fiscal/offline_queueing_provider.dart';

/// Круг повтора очереди фискализации.
///
/// # Почему 2 минуты
///
/// * Верхняя граница — автономное окно 72 ч: оно просторно, спешить незачем.
/// * Нижняя — стоимость прохода при лежащей связи: до
///   `maxConsecutiveTransient` (3) тайм-аутов клиента по 30 с, то есть до
///   90 с. Круг короче этого значил бы проходы встык, без паузы для сети и
///   оператора. Проходы и так не пересекаются (замок на хранилище), но
///   встык — это нагрузка без пользы.
/// * Обычный обрыв на кассе — минуты (роутер, провайдер). Две минуты от
///   восстановления до документа — меньше, чем кассир успеет заметить.
///
/// Связь, вернувшаяся раньше круга, узнаётся не таймером, а живым чеком:
/// [FiscalReplayScheduler.kick].
const Duration kFiscalReplayInterval = Duration(minutes: 2);

typedef FiscalReplayTarget = Future<OfflineQueueingProvider?> Function();

/// Повтор ждущих фискальных документов — **не только при старте кассы**.
///
/// # Что было
///
/// Повтор звался один раз, из `configureDependencies` при подъёме
/// (`replayPendingFiscal`). Чек, легший в очередь днём, ждал перезапуска
/// кассы — а кассу днём не перезапускают. К вечеру строка переживала окно
/// 72 ч только потому, что касса работала без остановки трое суток.
///
/// # Три входа
///
/// * [start] — первый проход сразу и круг [interval];
/// * [kick] — живой документ дошёл до оператора
///   (`OfflineQueueingProvider.onOperatorReached`): связь есть, ждать круга
///   незачем. Это единственный признак восстановленной связи в сборке
///   кассы: `isReachable` там — `() async => true`;
/// * [runOnce] — то же вручную.
///
/// Все три идут через `OfflineQueueingProvider.replay`, а у того проходы над
/// одним хранилищем не пересекаются: одновременные вызовы не отправят строку
/// дважды, а лишние сольются в один следующий проход.
///
/// # Почему не при закрытой смене
///
/// WebKassa открывает смену оператора **неявно** — первым документом
/// (`FiscalCapabilities.implicitShift`). Проход при закрытой смене кассы
/// (ночь после Z-отчёта, утро до открытия) открыл бы смену оператора, которую
/// никто не закроет: её Z-отчёт снимет утренний кассир, и в нём окажутся
/// ночные документы вчерашних продаж, а смена оператора старше 24 ч
/// отказывает кодом 12 уже на первой дневной продаже. Строки при этом не
/// теряются: окно 72 ч считается от продажи, и первый круг после открытия
/// смены их подберёт.
///
/// # Чего здесь нет
///
/// Таймер не заводится сам при сборке зависимостей: `configureDependencies`
/// гоняет и сквозной стенд набора (`test/e2e/support/harness.dart`), и
/// висящий периодический таймер ронял бы там каждый `testWidgets`. [start]
/// зовёт `main.dart`; до него [kick] ничего не делает.
class FiscalReplayScheduler {
  FiscalReplayScheduler({
    required FiscalReplayTarget resolve,
    required Future<bool> Function() isShiftOpen,
    Talker? logger,
    this.interval = kFiscalReplayInterval,
  }) : _resolve = resolve,
       _isShiftOpen = isShiftOpen,
       _logger = logger;

  final FiscalReplayTarget _resolve;
  final Future<bool> Function() _isShiftOpen;
  final Talker? _logger;
  final Duration interval;

  Timer? _timer;

  bool get isStarted => _timer != null;

  void start() {
    if (_timer != null) return;
    _timer = Timer.periodic(interval, (_) => unawaited(runOnce('круг')));
    unawaited(runOnce('старт'));
  }

  /// Связь с оператором подтверждена живым документом.
  void kick() {
    if (_timer == null) return;
    unawaited(runOnce('оператор ответил'));
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Один проход, если есть что везти и смена открыта. `null` — прохода не
  /// было (и почему — в журнале).
  Future<FiscalReplayReport?> runOnce([String reason = 'вручную']) async {
    try {
      final provider = await _resolve();
      if (provider == null) return null;
      if (await provider.pendingCount() == 0) return null;
      if (!await _isShiftOpen()) {
        _logger?.info(
          'Fiscal replay ($reason): смена кассы закрыта — проход отложен до '
          'открытия, чтобы не открыть смену оператора неявно',
        );
        return null;
      }
      final report = await provider.replay();
      _logger?.info(
        'Fiscal replay ($reason): fiscalized=${report.fiscalized} '
        'duplicates=${report.duplicates} failed=${report.failed} '
        'deferred=${report.deferred} held=${report.held} '
        'remaining=${report.remaining} '
        'stoppedOnNetwork=${report.stoppedOnNetwork}',
      );
      return report;
    } catch (e) {
      // Текст исключения в журнал не идёт — только тип (I144).
      _logger?.warning('Fiscal replay ($reason) failed: ${e.runtimeType}');
      return null;
    }
  }
}
