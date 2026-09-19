import 'package:decimal/decimal.dart';
import 'package:talker/talker.dart';

import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/sale/local_cart_service.dart';
import 'package:telepos/domain/sale/sale_checkout_service.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';

/// Кассовая реализация [SaleCheckoutService] — задача 8.
///
/// # Что перенесено и откуда
///
/// Из `SaleNotifier.completeSale` (`sale_controller.dart:377-522` до
/// правки) — всё, что там разговаривало с базой:
///
/// | Перенесено | Как легло |
/// | --- | --- |
/// | `thisPosDao.get()` ради `editPrice`/`sellInDiscount` | был `policy`; с задачи 44 — `LocalSaleEditTerms` |
/// | `_resolveSelectiveOfdDefault` | [selectiveOfdDefault] |
/// | проверка марок, остатков и потолка суммы | [prepare], отказом-значением |
/// | перезапись строк чека и суммы | [prepare] считает, `SaleUseCase.perform` записывает |
///
/// Почему счёт и запись разведены на два шага — в докстринге контракта
/// (решение круга правки 1 по C2 и C3). Почему запись живёт в транзакции
/// продажи, а не отдельным методом здесь, — там же, раздел про задачу 9.
class LocalSaleCheckoutService implements SaleCheckoutService {
  LocalSaleCheckoutService({
    required AppDatabase db,
    required LocalCartService cart,
    required Talker logger,
  }) : _db = db,
       _cart = cart,
       _logger = logger;

  final AppDatabase _db;
  final LocalCartService _cart;
  final Talker _logger;

  /// Потолок суммы чека, выше которого касса просит подтверждения
  /// настройкой `allowBigAmount`. Число перенесено из контроллера как есть.
  static final _bigAmountLimit = Decimal.parse('1000000');

  /// Разряды цены в завершённом чеке — денежные S3 (I159). То же число, с
  /// которым контроллер делил итог строки на количество.
  ///
  /// **Предел, измеренный кругом правки 1 и оставленный намеренно.** Скидка,
  /// не делящаяся нацело на количество, даёт цену единицы, умножение
  /// которой обратно на количество расходится с итогом строки на копейки:
  /// скидка 10 на трёх штуках по 100 даёт 96.666 за штуку и 289.998 против
  /// 290. Авторитет суммы — `Sales.amount`, и он верен; строки чека
  /// округлены до денег, потому что деньги в этом дереве — P18,S3, и
  /// десять знаков в цене завершённого чека уехали бы в фискальный
  /// документ и на печать. Расхождение существовало и до задачи 8
  /// (контроллер делил ровно так же); чем оно **перестало** быть — так это
  /// источником порчи корзины: запись случается внутри транзакции продажи
  /// (`SaleUseCase.perform`, задача 9) и обратно её никто не читает.
  static const _moneyScale = 3;

  @override
  Future<bool> selectiveOfdDefault() async {
    try {
      final pos = await _db.thisPosDao.get();
      if (pos == null) return false;
      if (!pos.sendToOfd) return false;
      return pos.ofdSyncType == 1;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<CheckoutPreparation> prepare({
    required int receiptNo,
    required int posId,
  }) async {
    final view = await _cart.viewOfReceipt(receiptNo, posId);
    if (view == null || view.lines.isEmpty) {
      return const CheckoutPreparation.refused(
        WireRefusal(checkoutEmptyCode, 'в чеке нет ни одной строки'),
      );
    }

    // Маркировка: маркируемый товар без кода не продаётся. Каталог
    // спрашивается один раз на товар, а не один раз на строку — тот же
    // ход, что был в контроллере.
    final markable = <int, bool>{};
    for (final line in view.lines) {
      if (markable.containsKey(line.productId)) continue;
      final info = await _db.productInfoDao.findByUcode(line.productId);
      markable[line.productId] = info?.isMarkable ?? false;
    }
    for (final line in view.lines) {
      final needsMark = markable[line.productId] ?? false;
      final mark = line.mark;
      if (needsMark && (mark == null || mark.trim().isEmpty)) {
        return CheckoutPreparation.refused(
          WireRefusal(checkoutMarkRequiredCode, line.name),
        );
      }
    }

    final pos = await _db.thisPosDao.get();

    if (pos?.blockOversell ?? false) {
      final wanted = <int, Decimal>{};
      for (final line in view.lines) {
        wanted[line.productId] =
            (wanted[line.productId] ?? Decimal.zero) + line.quantity;
      }
      for (final entry in wanted.entries) {
        final info = await _db.productInfoDao.findByUcode(entry.key);
        if (info == null) continue;
        final stock = info.quantity ?? Decimal.zero;
        if (entry.value > stock) {
          return CheckoutPreparation.refused(
            WireRefusal(checkoutInsufficientStockCode, info.name),
          );
        }
      }
    }

    if (!(pos?.allowBigAmount ?? false)) {
      if (view.total > _bigAmountLimit) {
        return const CheckoutPreparation.refused(
          WireRefusal(checkoutBigAmountCode, 'сумма чека выше потолка кассы'),
        );
      }
    }

    // Единственная запись подготовки, и она **не про корзину**: платежи
    // прежней попытки снимаются, иначе `SaleUseCase.perform` вставит свои
    // поверх и чек соберёт оплату дважды. Повторная попытка после отказа
    // терминала — обычный путь, а не авария.
    await _db.paymentDao.deleteBySale(receiptNo, posId);

    // Что записать вместе с продажей. Цены считаются здесь, а пишутся
    // внутри транзакции `SaleUseCase.perform` (задача 9) — до успеха
    // оплаты корзина обязана остаться корзиной (докстринг контракта,
    // решение по C2/C3).
    //
    // **Подарок акции живёт только здесь.** В базе акций нет вовсе: они
    // чистая функция от строк и таблицы `Promotions` и считаются при
    // сборке снимка (докстринг `LocalCartService`). `line.total` несёт
    // обе скидки — ручную и акционную, — и деление его на количество
    // единственный способ, которым подарок попадает в проданный чек.
    final lines = <ReceiptLine>[
      for (final line in view.lines)
        ReceiptLine(
          lineId: line.id,
          price: line.quantity > Decimal.zero
              ? (line.total / line.quantity).toDecimal(
                  scaleOnInfinitePrecision: _moneyScale,
                )
              : line.price,
          priceBefore: line.price,
          // Происхождение доезжает до проданного чека **снимком**, а не
          // выводом из цен: к этому шагу подарок акции и уступка кассира
          // дают одну и ту же разность (задача 13).
          discounts: line.discounts,
        ),
    ];

    _logger.info(
      'SaleCheckout: prepared receipt=$receiptNo pos=$posId '
      'lines=${lines.length} amount=${view.total}',
    );
    return CheckoutPreparation.ready(
      receiptNo: receiptNo,
      posId: posId,
      amount: view.total,
      lines: lines,
    );
  }

}
