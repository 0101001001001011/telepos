import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:talker/talker.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/mappers/sale_mapper.dart';
import 'package:telepos/data/sale/receipt_numbers.dart';
import 'package:telepos/domain/usecases/sale/sale_initiation_result.dart';
import 'package:telepos/domain/usecases/sale/sale_initiation_use_case.dart';
import 'package:telepos/domain/wire/wire_refusal.dart';

class SaleInitiationUseCaseImpl implements SaleInitiationUseCase {
  SaleInitiationUseCaseImpl({required AppDatabase db, required Talker logger})
    : _db = db,
      _logger = logger,
      _receiptNumbers = ReceiptNumbers(db);

  final AppDatabase _db;
  final Talker _logger;
  final ReceiptNumbers _receiptNumbers;

  static const int _stateInProgress = 0;

  @override
  Future<SaleInitiationResult> initiate({
    required int terminalId,
    bool isWholesale = false,
  }) async {
    final thisPos = await _db.thisPosDao.get();
    if (thisPos == null) {
      _logger.warning('SaleInitiation: ThisPos not found');
      return const SaleInitiationResult.refused(
        WireRefusal('till_not_configured', 'касса не настроена'),
      );
    }

    // Номер кассы проверяется **здесь**, до всякого поиска, а не после
    // ветки возобновления, как было до круга правки 4. Прежний
    // комментарий ниже утверждал, что пустой номер «отсеян выше», —
    // проверка стояла ниже, и утверждение было ложью, подтверждённой
    // пробой. Единая политика номера кассы: ноль не подставляется нигде;
    // отсутствие номера — названный отказ там, где контракт требует
    // значения (здесь), и бросок `TillNotConfigured` во всех прочих
    // местах (`ThisPosDao.requireId`).
    final posId = thisPos.id;
    if (posId == null) {
      _logger.warning('SaleInitiation: ThisPos has no id');
      return const SaleInitiationResult.refused(
        WireRefusal('till_not_configured', 'касса не настроена'),
      );
    }

    final weightRound = thisPos.weightProductRoundType;
    final discountRound = thisPos.discountsRoundType;

    // Рабочее место, за которым запущено это исполнение, — довод, а не
    // самовычисление. До задачи 5 эта строка была `(await
    // _db.terminalDao.self()).id ?? 0`: работало, пока единственный
    // вызывающий был сам кассой, но с браузерным терминалом (задачи 10, 12)
    // означало бы «беру терминал кассы вместо терминала вызывающего» — чек
    // уехал бы не тому рабочему месту. Касса (`sale_controller.dart`)
    // по-прежнему сама вычисляет свой `terminals.self()` и передаёт его
    // сюда доводом — самовычисление не исчезло, оно переехало к
    // вызывающему, которому единственному известно, кто он.
    //
    // Касса — второй довод поиска (круг правки 3 задачи 7): чек ищется по
    // паре «касса + место», иначе находился чек соседней кассы, попавший
    // в базу обменом.
    final existingSale = await _db.saleDao.findInProgress(
      posId: posId,
      terminalId: terminalId,
    );

    if (existingSale != null) {
      // **Возобновление не пишет в чек ничего** (круг правки 4).
      //
      // Здесь стояла запись `isWholesale` и обоих типов округления в уже
      // существующую строку. Оба решают, какая цена берётся строкой, и
      // оба менялись **без версии корзины** — сторож устаревшего снимка
      // такого изменения не видит по построению. Круг правки 3 снял с
      // этого пути своего вызывающего (`LocalCartService.start`), но
      // лечил вызывающего, а не пишущего: у метода есть второй и сегодня
      // главный вызывающий — `sale_controller._initSale`, зовущийся из
      // пяти мест, — и **повторный вход на экран продажи молча снимал
      // опт с начатого чека**, потому что состояние экрана по умолчанию
      // розничное.
      //
      // Возобновление по смыслу это «отдай, что есть», а не «примени мои
      // умолчания к чужой работе». Смена режима опта — своя команда
      // (`CartService.setWholesale`), идущая общим путём с версией.
      //
      // **Предел, оставленный сознательно (круг правки 5).** У правки есть
      // видимое следствие: настройки округления, изменённые посреди чека,
      // теперь расходятся между экраном кассы и строкой чека — контроллер
      // читает их в своё состояние сам (`_initSale`), а строка сохраняет
      // те, с которыми чек начат. Расхождение уйдёт с задачей 8, когда
      // экран перестанет держать свою копию и начнёт брать всё из снимка
      // корзины. Возвращать запись ради согласованности нельзя: она и
      // была дефектом — правила цен менялись под начатым чеком без версии.
      _logger.info(
        'SaleInitiation: resumed sale '
        'receipt=${existingSale.receiptNo}, pos=${existingSale.posId}',
      );
      return SaleInitiationResult.success(SaleMapper.fromDrift(existingSale));
    }

    final shift = await _db.shiftDao.findOpenedShift();
    if (shift == null) {
      // Задача 5: было — открыть смену самой, выбрав пользователя как
      // `userId ?? lastShift?.userId ?? 1`. На кассе это уже было спорно
      // (деньги легли бы на «последнего», без спроса); с браузерного
      // терминала — недопустимо: чек начал бы кто-то, кого никто не
      // спрашивал. Открытие смены остаётся отдельным действием кассы.
      _logger.info('SaleInitiation: no opened shift — refusing');
      return const SaleInitiationResult.refused(
        WireRefusal(
          'shift_not_open',
          'смена не открыта — откройте её на кассе',
        ),
      );
    }

    // Номер закрепляется атомарно, и строка рождается сразу полной — не
    // «прочитал последний, прибавил единицу» здесь на месте, и не
    // «бронь, потом UPDATE» (см. `ReceiptNumbers` за обеими причинами:
    // первая — два одновременных начала чека получали бы один и тот же
    // номер; вторая — авария между брoнью и её дозаполнением оставляла бы
    // в `Sales` строку без состояния, которую `findLastReceiptNo()` без
    // фильтра принял бы за настоящий последний чек).
    final nextReceiptNo = await _receiptNumbers.withNext(posId, (
      receiptNo,
    ) async {
      await _db
          .into(_db.sales)
          .insert(
            SalesCompanion.insert(
              receiptNo: receiptNo,
              posId: posId,
              userId: shift.userId,
              amount: Decimal.zero,
              time: 0,
              storeId: Value(thisPos.storeId),
              state: const Value(_stateInProgress),
              isWholesale: Value(isWholesale),
              weightProductRoundType: Value(weightRound),
              discountsRoundType: Value(discountRound),
              isOfd: const Value(false),
              // Владелец — I156: `state = 0` без хозяина был бы ровно тем
              // молчаливым умолчанием, ради которого `findInProgress` теперь
              // требует довод (см. выше).
              terminalId: Value(terminalId),
            ),
          );
      return receiptNo;
    });

    _logger.info(
      'SaleInitiation: created new sale '
      'receipt=$nextReceiptNo, pos=$posId, user=${shift.userId}',
    );

    final created = await _db.saleDao.findInProgress(
      posId: posId,
      terminalId: terminalId,
    );
    return SaleInitiationResult.success(SaleMapper.fromDrift(created!));
  }
}
