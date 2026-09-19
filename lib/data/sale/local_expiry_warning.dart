import 'package:telepos/domain/sale/expiry_warning.dart';
import 'package:telepos/domain/usecases/wms/batch_tracking_use_case.dart';
import 'package:telepos/domain/usecases/wms/wms_config_use_case.dart';

/// Кассовая половина [ExpiryWarningReader] — пункт 11 ревизии 2026-09-19.
///
/// Тот же расчёт, что жил в `SaleNotifier._checkExpiryWarning` до этой
/// правки, но **на кассе** и за одним договором. Ничего нового он не считает
/// — это перенос, а не новая проверка; новое здесь только то, что его теперь
/// достижимо спросить с планшета.
///
/// # Почему стратегия отбора берётся через юзкейс, а не читается настройкой
///
/// `WmsConfigUseCase.pickingStrategy()` сводит три источника правды к одному
/// ответу: явный токен настройки, старые тумблеры `enableFefo`/`enableFifo`
/// и умолчание. Читать настройку мимо него значило бы завести четвёртый
/// источник — и разойтись с отбором, который делает списание.
///
/// # Отказ настройки не гасит предупреждение
///
/// Если `pickingStrategy()` бросил, берётся `FEFO` — та же ветка, что была в
/// контроллере. Довод не «на всякий случай»: FEFO отдаёт партию с ближайшим
/// сроком, то есть **самую вероятную просроченную**. Ошибиться в сторону
/// предупреждения дешевле, чем промолчать о просрочке из-за нечитаемой
/// настройки склада.
///
/// # Чего это НЕ доказывает
///
/// Что товар списан именно этой партией: [BatchTrackingUseCase
/// .suggestBatchForPicking] отвечает «какую бы отдал отбор сейчас» и ничего
/// не резервирует. Между вопросом и оплатой партия может уйти соседней
/// кассой.
class LocalExpiryWarning implements ExpiryWarningReader {
  LocalExpiryWarning({
    required this.batches,
    required this.wmsConfig,
    this.now = DateTime.now,
  });

  final BatchTrackingUseCase batches;
  final WmsConfigUseCase wmsConfig;

  /// Час, к которому сравнивается срок. Подменяется в пробах: «просрочено»
  /// — утверждение про **сейчас**, и проба, закрепившая дату в семенах,
  /// но не время сравнения, через год начала бы мерить календарь, а не код.
  final DateTime Function() now;

  @override
  Future<bool> isPickedBatchExpired(int productId) async {
    var strategy = 'FEFO';
    try {
      strategy = await wmsConfig.pickingStrategy();
    } catch (_) {
      // Настройка склада нечитаема — см. довод в докстринге класса.
    }
    final picked = await batches.suggestBatchForPicking(productId, strategy);
    final expiry = picked?.expiryDate;
    if (expiry == null) return false;
    return expiry < now().millisecondsSinceEpoch ~/ 1000;
  }
}
