import 'package:telepos/domain/sale/sale_edit_terms.dart';
import 'package:telepos/domain/wire/sale_ops.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';
import 'package:telepos/web/wt_channel.dart';
import 'package:telepos/web/wt_dispatcher.dart';

/// Условия правки строки с браузерного терминала — вторая реализация
/// [SaleEditTermsReader] (задача 44). Первая — кассовая `LocalSaleEditTerms`.
///
/// **Довод `by` по проводу не отправляется.** Полномочия касса строит из
/// сеанса кадра (`TillOperations._authorityOf`); отправить их отсюда значило
/// бы предложить кассе поверить вкладке, и кассир назвал бы себя владельцем
/// ради чужого предела. Довод обязателен по контракту потому, что контракт
/// один на два фронта, — тем же правилом живёт `WtCartService`.
///
/// Отказ кассы приходит [WireRefusal] с кодом кассы — тем же типом, каким его
/// бросает кассовая реализация, чтобы `on WireRefusal` контроллера ловил обе.
class WtSaleEditTerms implements SaleEditTermsReader {
  WtSaleEditTerms(this._wire);

  final WtDispatcher _wire;

  @override
  Future<SaleEditTerms> read({required DiscountAuthority by}) async {
    try {
      return await _wire.ask(SaleOps.editTerms, null);
    } on WtProtocolError catch (error) {
      throw WireRefusal(error.code, error.detail);
    }
  }
}
