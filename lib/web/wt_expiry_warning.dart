import 'package:telepos/domain/sale/expiry_warning.dart';
import 'package:telepos/domain/wire/till_ops.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';
import 'package:telepos/web/wt_channel.dart';
import 'package:telepos/web/wt_dispatcher.dart';

/// Браузерная половина [ExpiryWarningReader] — пункт 11 ревизии 2026-09-19.
///
/// # Что было
///
/// `SaleNotifier._checkExpiryWarning` спрашивал `BatchTrackingUseCase` через
/// `GetIt.I.isRegistered`, а браузер его не привязывает: партии живут в базе
/// кассы. Развилка молча отвечала «не смотрим», и кассир за планшетом
/// пробивал просроченный товар без единого слова на экране. Обе стороны
/// развилки стояли записью ОТКРЫТО в `presentation_is_registered_test.dart` и
/// в списке исключений `browser_routes_test.dart`.
///
/// # Чего это НЕ доказывает
///
/// Что предупреждение появится **до** оплаты во всех случаях. Вопрос уходит
/// после того, как строка встала в чек, и ответ приходит по проводу: кассир,
/// успевший нажать «ОПЛАТИТЬ» раньше ответа, увидит снекбар уже на экране
/// оплаты или не увидит вовсе. Так же ведёт себя и касса — там вопрос тоже
/// асинхронный; провод добавляет к задержке сеть, но не меняет род
/// поведения. Предупреждение запретом не является ни на одном конце.
class WtExpiryWarning implements ExpiryWarningReader {
  WtExpiryWarning(this._wire);

  final WtDispatcher _wire;

  @override
  Future<bool> isPickedBatchExpired(int productId) async {
    try {
      return await _wire.ask(TillOps.saleExpiryWarning, productId);
    } on WtProtocolError catch (error) {
      throw WireRefusal(error.code, error.detail);
    }
  }
}
