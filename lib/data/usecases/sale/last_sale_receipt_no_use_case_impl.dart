import 'package:drift/drift.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/domain/usecases/sale/last_sale_receipt_no_use_case.dart';

class LastSaleReceiptNoUseCaseImpl implements LastSaleReceiptNoUseCase {
  LastSaleReceiptNoUseCaseImpl({
    required AppDatabase db,
    required Talker logger,
  }) : _db = db,
       _logger = logger;

  final AppDatabase _db;
  final Talker _logger;

  @override
  Future<void> perform() async {
    final int? serverLastReceiptNo = await _fetchLastReceiptNoFromServer();

    if (serverLastReceiptNo == null) {
      _logger.info('LastSaleReceiptNo: server unavailable, using local');
      return;
    }

    final localLastReceiptNo = await _db.saleDao.findLastReceiptNo() ?? 0;

    if (serverLastReceiptNo != 0 && localLastReceiptNo < serverLastReceiptNo) {
      await _renumberInProgressSale(serverLastReceiptNo);
    }
  }

  Future<int?> _fetchLastReceiptNoFromServer() async {
    return null;
  }

  /// **Предел, названный кругом правки 5 задачи 7: перенумерация теряет
  /// состояние корзины.** Метод пересоздаёт строку чека под новым номером
  /// и переносит товары — но `cartVersion`, `lastCommandKey` и оба типа
  /// округления в новую строку не переносятся. Для браузерного терминала
  /// это значит: версия у чека внезапно ноль (все команды в полёте
  /// получат `cart_stale` — безопасно, но необъяснимо), ключ повтора
  /// потерян (честный повтор применится вторым разом), а замороженные
  /// правила округления заменятся умолчанием — то есть **цены строк могут
  /// измениться**.
  ///
  /// Не чинится здесь по решению координатора: код сегодня недостижим —
  /// `_fetchLastReceiptNoFromServer()` возвращает `null` всегда (сервер
  /// снят вместе с Go-бэкендом), и до перенумерации исполнение не
  /// доходит. Оживёт этот путь — правку делать здесь, вместе с переносом
  /// трёх колонок.
  Future<void> _renumberInProgressSale(int serverLastReceiptNo) async {
    // Перенумеровывается чек **этого** рабочего места. До v37 рабочее место
    // было одно и `findInProgress()` не могло взять чужое; с браузерным
    // терминалом это стало возможно — без довода этот код перенумеровал бы
    // (и переносил бы товары) чек, который в этот момент набирает другое
    // рабочее место, из-под него. Единственный вызывающий этот код сегодня —
    // сама касса (её терминал — `terminals.self`, тот же сентинел `?? 0`,
    // что и в `SaleInitiationUseCaseImpl`).
    final terminalId = (await _db.terminalDao.self())?.id ?? 0;

    // Касса читается до поиска: чек ищется по паре «касса + место», а не
    // по одному месту (круг правки 3 задачи 7 — иначе нашёлся бы чек
    // соседней кассы, попавший в базу обменом, и перенумерован был бы он).
    // Единая политика номера кассы (`ThisPosDao.requireId`, круг правки 4
    // задачи 7): ноль не подставляется — он настоящий номер кассы, и
    // запрос с ним нашёл бы чужие строки. Ненастроенная касса роняет эту
    // задачу броском; единственный вызывающий (`initialization_task`) уже
    // ловит и пишет в журнал, то есть наблюдаемый исход тот же, что был у
    // прежнего раннего выхода, но без тихой подстановки чужого номера.
    final posId = await _db.thisPosDao.requireId();

    final inProgressSale = await _db.saleDao.findInProgress(
      posId: posId,
      terminalId: terminalId,
    );
    if (inProgressSale == null) {
      return;
    }

    final newReceiptNo = serverLastReceiptNo + 1;
    final oldReceiptNo = inProgressSale.receiptNo;
    final oldPosId = inProgressSale.posId;

    _logger.info(
      'LastSaleReceiptNo: renumbering receipt $oldReceiptNo → $newReceiptNo',
    );

    await _db.transaction(() async {
      await (_db.delete(_db.sales)..where(
            (s) => s.receiptNo.equals(oldReceiptNo) & s.posId.equals(oldPosId),
          ))
          .go();

      final newPosId = posId;
      final saleProducts = await _db.saleProductDao.findBySale(
        oldReceiptNo,
        oldPosId,
      );
      for (final sp in saleProducts) {
        await _db
            .into(_db.saleProducts)
            .insert(
              SaleProductsCompanion.insert(
                ucode: sp.ucode,
                quantity: sp.quantity,
                price: sp.price,
                priceBefore: sp.priceBefore,
                receiptNo: Value(newReceiptNo),
                posId: Value(newPosId),
                barcode: Value(sp.barcode),
                categoryId: Value(sp.categoryId),
              ),
            );
      }

      final universalProducts = await _db.saleProductDao.findUniversalBySale(
        oldReceiptNo,
        oldPosId,
      );
      for (final up in universalProducts) {
        await _db
            .into(_db.universalProducts)
            .insert(
              UniversalProductsCompanion.insert(
                quantity: up.quantity,
                price: up.price,
                receiptNo: Value(newReceiptNo),
                posId: Value(newPosId),
                priceBefore: Value(up.priceBefore),
              ),
            );
      }

      await _db
          .into(_db.sales)
          .insert(
            SalesCompanion.insert(
              receiptNo: newReceiptNo,
              posId: newPosId,
              userId: inProgressSale.userId,
              amount: inProgressSale.amount,
              time: inProgressSale.time,
              state: Value(0),
              isOfd: Value(inProgressSale.isOfd),
              isWholesale: Value(inProgressSale.isWholesale),
              // Владелец переносится вместе с чеком: перенумерованная
              // строка остаётся чеком того же рабочего места (I156), а не
              // чеком-сиротой, который завтра найдёт себе кто попало.
              terminalId: Value(inProgressSale.terminalId),
            ),
          );
    });
  }
}
