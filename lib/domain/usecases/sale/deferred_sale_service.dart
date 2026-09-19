abstract class DeferredSaleService {
  Future<void> deferSale({required int receiptNo});

  /// Поднимает отложенный чек [receiptNo] рабочему месту [terminalId].
  ///
  /// **`terminalId` — довод, а не догадка (задача 17).** До неё метод
  /// вычислял владельца сам, `terminals.self() ?? 0`, то есть всегда
  /// приписывал поднятый чек **кассе**, кто бы его ни поднял. С
  /// браузерным терминалом это стало кражей владения: девятое место
  /// поднимает чек, а хозяином строки становится первое.
  ///
  /// **`null` значит «чек не был отложен» — и это не ошибка вызова, а
  /// исход гонки.** Поднимает того, у кого `state = 3`, одним условным
  /// обновлением: двое, поднявших один чек, разводятся базой, а не
  /// порядком строк в коде. Проигравший получает `null` и обязан
  /// объяснить это человеку названной причиной.
  ///
  /// Метод **ничего не удаляет.** До задачи 17 он молча сносил чек в
  /// работе, чтобы освободить место, — приём времён, когда рабочее место
  /// на кассе было ровно одно, а корзина жила в памяти. Теперь строки
  /// лежат в базе с первой команды, и «освободить место» — решение
  /// вызывающего (`LocalCartService.loadDeferred` отвечает на это отказом
  /// `cart_not_empty`), а не тихое действие этого метода.
  Future<dynamic> undeferSale({
    required int receiptNo,
    required int terminalId,
  });

  Future<List<dynamic>> getDeferredSales();

  Future<List<DeferredSaleProduct>> getProducts({
    required int receiptNo,
    required int posId,
  });
}

class DeferredSaleProduct {
  const DeferredSaleProduct({
    required this.ucode,
    required this.name,
    required this.quantity,
    required this.price,
  });

  final int ucode;

  final String name;

  final dynamic quantity;

  final dynamic price;
}
